import AVFoundation

/// Serializes session transitions without blocking the UI. A newer playback
/// request supersedes any playback still waiting for activation.
@MainActor
final class AudioSessionController {
    private let activate: () async throws -> Void
    private let deactivate: () async throws -> Void
    private var pendingOperation: Task<Void, Never>?
    private var requestID = UUID()

    init(
        activate: @escaping () async throws -> Void = AudioSessionController.activateSession,
        deactivate: @escaping () async throws -> Void = AudioSessionController.deactivateSession
    ) {
        self.activate = activate
        self.deactivate = deactivate
    }

    func play(
        afterStopping stopPlayback: @escaping () async -> Void = {},
        _ startPlayback: @escaping () async throws -> Void
    ) {
        let id = UUID()
        requestID = id
        enqueue {
            guard self.requestID == id else { return }
            await stopPlayback()
            guard self.requestID == id else { return }
            do {
                try await self.activate()
                guard self.requestID == id else { return }
                try await startPlayback()
            } catch {
                print("Error starting audio playback: \(error)")
                guard self.requestID == id else { return }
                try? await self.deactivate()
            }
        }
    }

    func deactivateWhenIdle() {
        let id = requestID
        enqueue {
            guard self.requestID == id else { return }
            try? await self.deactivate()
        }
    }

    private func enqueue(_ operation: @escaping () async -> Void) {
        let previous = pendingOperation
        pendingOperation = Task {
            await previous?.value
            await operation()
        }
    }

    private static func activateSession() async throws {
        if !isConfigured {
            try await performSessionOperation {
                // Duck background music only while a pronunciation is playing.
                try $0.setCategory(.playback, mode: .default, options: .duckOthers)
            }
            isConfigured = true
        }
        // Xcode 27's SDK adds these APIs. Older toolchains keep using the
        // background-queue fallback, including when running on newer iOS.
        #if compiler(>=6.4)
        if #available(iOS 27.0, *) {
            guard try await AVAudioSession.sharedInstance().activate(options: []) else {
                throw SessionError.activationFailed
            }
            return
        }
        #endif
        try await setLegacyActive(true)
    }

    private static func deactivateSession() async throws {
        #if compiler(>=6.4)
        if #available(iOS 27.0, *) {
            _ = try await AVAudioSession.sharedInstance().deactivate(options: .notifyOthersOnDeactivation)
            return
        }
        #endif
        try await setLegacyActive(false)
    }

    private enum SessionError: Error {
        case activationFailed
    }

    private static var isConfigured = false
    private nonisolated static let legacyQueue = DispatchQueue(label: "net.montpetit.thaisheet.audio-session")

    private nonisolated static func setLegacyActive(_ active: Bool) async throws {
        try await performSessionOperation {
            try $0.setActive(active, options: active ? [] : .notifyOthersOnDeactivation)
        }
    }

    private nonisolated static func performSessionOperation(
        _ operation: @escaping @Sendable (AVAudioSession) throws -> Void
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            legacyQueue.async {
                do {
                    try operation(AVAudioSession.sharedInstance())
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
