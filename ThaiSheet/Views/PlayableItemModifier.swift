//
//  PlayableItemModifier.swift
//  ThaiSheet
//

import SwiftUI

/// Unified interaction for reference items: tap plays the sound (falling back to
/// the details sheet when the item has none), long press opens the details sheet.
/// Also restores the button semantics for VoiceOver that bare gestures would lose.
struct PlayableItemModifier: ViewModifier {
    /// Spoken VoiceOver label for the whole item (Thai text reads in Thai)
    let label: String
    let hasSound: Bool
    let onPlay: () -> Void
    let onDetails: () -> Void

    private var hint: String {
        hasSound
            ? String(localized: "Plays the sound. Touch and hold for details.", bundle: .appLanguage)
            : String(localized: "Shows details.", bundle: .appLanguage)
    }

    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .onTapGesture {
                if hasSound {
                    onPlay()
                } else {
                    onDetails()
                }
            }
            .onLongPressGesture {
                onDetails()
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityHint(hint)
            .accessibilityAddTraits(.isButton)
    }
}

extension View {
    /// Tap plays the sound (details sheet when there is none), long press opens details.
    func playableItem(
        label: String,
        hasSound: Bool,
        onPlay: @escaping () -> Void,
        onDetails: @escaping () -> Void
    ) -> some View {
        modifier(PlayableItemModifier(
            label: label,
            hasSound: hasSound,
            onPlay: onPlay,
            onDetails: onDetails
        ))
    }
}
