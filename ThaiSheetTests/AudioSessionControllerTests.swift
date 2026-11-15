import XCTest
@testable import ThaiSheet

@MainActor
final class AudioSessionControllerTests: XCTestCase {
    func test_playbackWaitsForActivation() async {
        let activating = expectation(description: "activation started")
        let playing = expectation(description: "playback started")
        var gate: CheckedContinuation<Void, Never>?
        var didPlay = false
        let controller = AudioSessionController(activate: {
            await withCheckedContinuation {
                gate = $0
                activating.fulfill()
            }
        }, deactivate: {})

        controller.play {
            didPlay = true
            playing.fulfill()
        }
        await fulfillment(of: [activating], timeout: 2)
        XCTAssertFalse(didPlay)
        gate?.resume()
        await fulfillment(of: [playing], timeout: 2)
    }

    func test_newRequestSupersedesPlaybackWaitingForActivation() async {
        let activating = expectation(description: "first activation started")
        let playing = expectation(description: "latest playback started")
        var gate: CheckedContinuation<Void, Never>?
        var activations = 0
        var played: [String] = []
        let controller = AudioSessionController(activate: {
            activations += 1
            if activations == 1 {
                await withCheckedContinuation {
                    gate = $0
                    activating.fulfill()
                }
            }
        }, deactivate: {})

        controller.play { played.append("first") }
        await fulfillment(of: [activating], timeout: 2)
        controller.play { played.append("second") }
        controller.play {
            played.append("third")
            playing.fulfill()
        }
        gate?.resume()
        await fulfillment(of: [playing], timeout: 2)
        XCTAssertEqual(played, ["third"])
        XCTAssertEqual(activations, 2)
    }

    func test_queuedDeactivationDoesNotInterruptNewPlayback() async {
        let first = expectation(description: "first playback started")
        let second = expectation(description: "second playback started")
        var deactivations = 0
        let controller = AudioSessionController(activate: {}, deactivate: { deactivations += 1 })

        controller.play { first.fulfill() }
        await fulfillment(of: [first], timeout: 2)
        controller.deactivateWhenIdle()
        controller.play { second.fulfill() }
        await fulfillment(of: [second], timeout: 2)
        XCTAssertEqual(deactivations, 0)
    }

    func test_newPlaybackWaitsForInFlightDeactivation() async {
        let first = expectation(description: "first playback started")
        let deactivating = expectation(description: "deactivation started")
        let second = expectation(description: "second playback started")
        var gate: CheckedContinuation<Void, Never>?
        var events: [String] = []
        let controller = AudioSessionController(activate: {
            events.append("activate")
        }, deactivate: {
            events.append("deactivate")
            await withCheckedContinuation {
                gate = $0
                deactivating.fulfill()
            }
            events.append("deactivated")
        })

        controller.play { first.fulfill() }
        await fulfillment(of: [first], timeout: 2)
        controller.deactivateWhenIdle()
        await fulfillment(of: [deactivating], timeout: 2)
        controller.play { second.fulfill() }
        XCTAssertEqual(events, ["activate", "deactivate"])
        gate?.resume()
        await fulfillment(of: [second], timeout: 2)
        XCTAssertEqual(events, ["activate", "deactivate", "deactivated", "activate"])
    }

    func test_activationFailureDoesNotStartPlayback_andReleasesSession() async {
        let deactivated = expectation(description: "failed session released")
        let controller = AudioSessionController(activate: {
            throw TestError.failed
        }, deactivate: { deactivated.fulfill() })

        controller.play { XCTFail("Playback requires successful activation") }
        await fulfillment(of: [deactivated], timeout: 2)
    }

    func test_playbackFailureReleasesSession() async {
        let deactivated = expectation(description: "session released after playback error")
        let controller = AudioSessionController(activate: {}, deactivate: { deactivated.fulfill() })

        controller.play { throw TestError.failed }
        await fulfillment(of: [deactivated], timeout: 2)
    }

    func test_supersededRequestWaitingForStopCannotActivateOrStart() async {
        let stopping = expectation(description: "old playback stopping")
        let playing = expectation(description: "latest playback started")
        var gate: CheckedContinuation<Void, Never>?
        var events: [String] = []
        let controller = AudioSessionController(activate: {
            events.append("activate")
        }, deactivate: {})

        controller.play(afterStopping: {
            await withCheckedContinuation {
                gate = $0
                stopping.fulfill()
            }
        }) { XCTFail("Superseded request must not start") }
        await fulfillment(of: [stopping], timeout: 2)
        controller.play(afterStopping: { events.append("stop") }) {
            events.append("play")
            playing.fulfill()
        }
        XCTAssertTrue(events.isEmpty)
        gate?.resume()
        await fulfillment(of: [playing], timeout: 2)
        XCTAssertEqual(events, ["stop", "activate", "play"])
    }

    private enum TestError: Error {
        case failed
    }
}
