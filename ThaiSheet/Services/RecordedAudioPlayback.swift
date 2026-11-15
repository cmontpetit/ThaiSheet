import AVFoundation

/// AVAudioPlayer.play() and stop() synchronously acquire/release audio hardware,
/// even after explicit session activation. Confine the entire player lifecycle
/// to a serial executor backed by a background dispatch queue.
actor RecordedAudioPlayback {
    private nonisolated let queue = DispatchSerialQueue(label: "net.montpetit.thaisheet.recorded-playback")
    nonisolated var unownedExecutor: UnownedSerialExecutor { queue.asUnownedSerialExecutor() }

    private var player: AVAudioPlayer?
    private var delegate: PlaybackDelegate?
    private var playbackID: UUID?

    func play(_ url: URL, onFinish: @escaping @MainActor @Sendable () -> Void) throws {
        stop()
        let id = UUID()
        let player = try AVAudioPlayer(contentsOf: url)
        let delegate = PlaybackDelegate { [weak self] in
            Task { await self?.finish(id, onFinish: onFinish) }
        }
        self.player = player
        self.delegate = delegate
        playbackID = id
        player.delegate = delegate
        guard player.play() else {
            stop()
            throw PlaybackError.failedToStart
        }
    }

    func stop() {
        playbackID = nil
        player?.stop()
        player = nil
        delegate = nil
    }

    private func finish(_ id: UUID, onFinish: @MainActor @Sendable () -> Void) async {
        guard playbackID == id else { return }
        playbackID = nil
        player = nil
        delegate = nil
        await onFinish()
    }

    private enum PlaybackError: Error {
        case failedToStart
    }
}

/// AVFoundation may deliver callbacks on a different thread from the caller.
/// Only the immutable Sendable callback crosses that boundary; player state
/// stays on RecordedAudioPlayback's executor.
private final class PlaybackDelegate: NSObject, AVAudioPlayerDelegate, Sendable {
    private nonisolated let onFinish: @Sendable () -> Void

    nonisolated init(onFinish: @escaping @Sendable () -> Void) {
        self.onFinish = onFinish
        super.init()
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onFinish()
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        onFinish()
    }
}
