//
//  PracticeMode.swift
//  ThaiSheet
//

import SwiftUI

/// Reference-tab practice state: when active, readings (romanization, tone
/// results) are blurred so the user can self-test. Tapping a row plays its
/// sound and reveals that row's reading; tapping the same row again re-blurs
/// it, and tapping a different row moves the single reveal there. The eye
/// toolbar button is a pure on/off switch — activation always starts fully
/// blurred, so its meaning never depends on reveal history.
@Observable
final class PracticeMode {
    var isActive = false
    var revealedID: String? = nil

    func toggleActive() {
        isActive.toggle()
        revealedID = nil
    }

    func isConcealed(_ id: String) -> Bool {
        isActive && revealedID != id
    }

    /// Row tap on the sole tap target for a reading: reveal it, or re-conceal
    /// it if it was already the revealed one.
    func handleTap(_ id: String) {
        guard isActive else { return }
        revealedID = (revealedID == id) ? nil : id
    }

    /// Reveal a reading without toggling. Used when several tap targets share
    /// one reading (a vowel row's form cells): tapping a sibling cell to hear a
    /// different form should keep the answer shown, not hide it.
    func reveal(_ id: String) {
        guard isActive else { return }
        revealedID = id
    }
}

// MARK: - Environment

private struct PracticeModeKey: EnvironmentKey {
    /// Inactive default so sheets, flashcards, and previews are unaffected.
    static let defaultValue = PracticeMode()
}

extension EnvironmentValues {
    var practiceMode: PracticeMode {
        get { self[PracticeModeKey.self] }
        set { self[PracticeModeKey.self] = newValue }
    }
}

// MARK: - Conceal modifier

extension View {
    /// Blurs a reading while practice mode conceals it. Desaturates too:
    /// tone chips are color-coded, so a colored smudge would leak the answer.
    func concealedReading(_ concealed: Bool) -> some View {
        self
            .saturation(concealed ? 0 : 1)
            .blur(radius: concealed ? 5 : 0)
            .animation(.easeInOut(duration: 0.15), value: concealed)
    }
}
