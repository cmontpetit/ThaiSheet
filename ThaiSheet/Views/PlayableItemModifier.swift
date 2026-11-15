//
//  PlayableItemModifier.swift
//  ThaiSheet
//

import SwiftUI

/// The single interaction contract for a reference item: tap plays the sound
/// and selects inline details on wide containers; long press opens details. When a
/// `PracticeConceal` is supplied it also owns the practice-mode contract —
/// reveal-on-tap, the concealed VoiceOver label, and the concealed hint — so
/// individual rows can't forget a step and silently leak the answer.
struct PlayableItemModifier: ViewModifier {
    /// Spoken VoiceOver label for the whole item (Thai text reads in Thai)
    let label: String
    let hasSound: Bool
    let conceal: PracticeConceal?
    let item: ReferenceItem
    let onPlay: () -> Void

    @Environment(\.practiceMode) private var practiceMode
    @Environment(\.referenceSelection) private var selection

    private var isSelected: Bool {
        selection?.isExpanded == true && selection?.item?.id == item.id
    }

    private var isConcealed: Bool {
        guard let conceal else { return false }
        return practiceMode.isConcealed(conceal.id)
    }

    /// Concealed items announce the question only; the reading is withheld.
    private var effectiveLabel: String {
        isConcealed ? (conceal?.concealedLabel ?? label) : label
    }

    /// Describes what a tap actually does, given practice state. In practice
    /// mode a tap reveals a concealed reading, re-hides a revealed toggle item,
    /// and plays the sound when there is one; a revealed reveal-only cell only
    /// re-plays (or does nothing without audio).
    private var hint: String {
        if selection?.isExpanded == true {
            if let conceal, practiceMode.isActive {
                if practiceMode.isConcealed(conceal.id) {
                    return hasSound
                        ? String(localized: "Plays the sound, reveals the answer, and shows details.", bundle: .appLanguage)
                        : String(localized: "Reveals the answer and shows details.", bundle: .appLanguage)
                }
                if !conceal.revealOnly {
                    return hasSound
                        ? String(localized: "Plays the sound and hides the answer.", bundle: .appLanguage)
                        : String(localized: "Hides the answer.", bundle: .appLanguage)
                }
            }
            return hasSound
                ? String(localized: "Plays the sound and shows details.", bundle: .appLanguage)
                : String(localized: "Shows details.", bundle: .appLanguage)
        }
        guard let conceal, practiceMode.isActive else {
            return hasSound
                ? String(localized: "Plays the sound. Touch and hold for details.", bundle: .appLanguage)
                : String(localized: "Shows details.", bundle: .appLanguage)
        }
        if practiceMode.isConcealed(conceal.id) {
            return hasSound
                ? String(localized: "Plays the sound and reveals the answer. Touch and hold for details.", bundle: .appLanguage)
                : String(localized: "Reveals the answer. Touch and hold for details.", bundle: .appLanguage)
        }
        if conceal.revealOnly {
            return hasSound
                ? String(localized: "Plays the sound. Touch and hold for details.", bundle: .appLanguage)
                : String(localized: "Touch and hold for details.", bundle: .appLanguage)
        }
        return hasSound
            ? String(localized: "Plays the sound and hides the answer. Touch and hold for details.", bundle: .appLanguage)
            : String(localized: "Hides the answer. Touch and hold for details.", bundle: .appLanguage)
    }

    private func applyConceal() {
        guard let conceal else { return }
        if conceal.revealOnly {
            practiceMode.reveal(conceal.id)
        } else {
            practiceMode.handleTap(conceal.id)
        }
    }

    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .onTapGesture {
                // In practice mode a tap reveals (or re-hides) this item's reading
                // and still plays its sound if it has one — so even a no-audio row
                // can be revealed. Details stay reachable via long press. Outside
                // practice mode: play, or open details when there's no sound.
                if conceal != nil, practiceMode.isActive {
                    applyConceal()
                    if hasSound { onPlay() }
                } else if hasSound {
                    onPlay()
                } else {
                    selection?.showDetails(item)
                }
                selection?.selectFromTap(item)
            }
            .onLongPressGesture {
                selection?.showDetails(item)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 1.5)
                    .allowsHitTesting(false)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(effectiveLabel)
            .accessibilityHint(hint)
            .accessibilityAddTraits(.isButton)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            // An explicit, tap-free route to details for assistive-technology
            // users: long press is a poor primary path for motor impairments,
            // and this doesn't depend on discovering the ⓘ "how to use" popover.
            .accessibilityAction(named: Text("Show details")) {
                selection?.showDetails(item)
            }
    }
}

extension View {
    /// Tap plays and selects inline details; compact containers use a details sheet.
    /// Pass `conceal` to opt the item into practice mode's hide/reveal contract.
    func playableItem(
        label: String,
        hasSound: Bool,
        conceal: PracticeConceal? = nil,
        item: ReferenceItem,
        onPlay: @escaping () -> Void
    ) -> some View {
        modifier(PlayableItemModifier(
            label: label,
            hasSound: hasSound,
            conceal: conceal,
            item: item,
            onPlay: onPlay
        ))
    }
}
