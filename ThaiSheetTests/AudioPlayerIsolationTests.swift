import AVFoundation
import XCTest
@testable import ThaiSheet

final class AudioPlayerIsolationTests: XCTestCase {
    nonisolated func test_speechDelegateCallbacksCanArriveOutsideMainActor() async {
        let player = await AudioPlayer()
        let synthesizer = AVSpeechSynthesizer()
        let utterance = AVSpeechUtterance(string: "กอไก่")

        // AVFoundation's delegate requirements are nonisolated. These stale
        // callbacks must safely return to MainActor and leave playback alone.
        player.speechSynthesizer(synthesizer, didFinish: utterance)
        player.speechSynthesizer(synthesizer, didCancel: utterance)
        await Task.yield()
    }
}
