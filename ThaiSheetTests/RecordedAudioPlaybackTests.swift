import XCTest
@testable import ThaiSheet

@MainActor
final class RecordedAudioPlaybackTests: XCTestCase {
    // Exercise the real AVAudioPlayer path, including its implicit hardware
    // activation and delegate delivery from the background playback executor.
    func test_bundledClipFinishesAndReturnsToMainActor() async throws {
        let finished = expectation(description: "recorded clip finished")
        let playback = RecordedAudioPlayback()
        let url = try XCTUnwrap(Bundle.main.url(
            forResource: "cheat_sheet_sample_word_ไก่_neural2", withExtension: "mp3"
        ))

        try await playback.play(url) {
            MainActor.preconditionIsolated()
            finished.fulfill()
        }
        await fulfillment(of: [finished], timeout: 10)
        await playback.stop()
    }

    func test_missingClipThrows_withoutReportingCompletion() async {
        let playback = RecordedAudioPlayback()
        do {
            try await playback.play(URL(fileURLWithPath: "/no-such-thaisheet-clip.mp3")) {
                XCTFail("A missing clip cannot finish playback")
            }
            XCTFail("A missing clip must throw")
        } catch {
            // The session controller handles this error by releasing the session.
        }
        await playback.stop()
    }

    func test_replacementOnlyReportsCompletionOfLatestClip() async throws {
        let finished = expectation(description: "replacement clip finished")
        let playback = RecordedAudioPlayback()
        let url = try XCTUnwrap(Bundle.main.url(
            forResource: "cheat_sheet_sample_word_ไก่_neural2", withExtension: "mp3"
        ))

        try await playback.play(url) {
            XCTFail("A replaced clip must not deactivate the new clip's session")
        }
        try await playback.play(url) { finished.fulfill() }
        await fulfillment(of: [finished], timeout: 10)
        await playback.stop()
    }
}
