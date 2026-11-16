//
//  ScreenshotScenario.swift
//  ThaiSheet
//
//  Deterministic App Store screenshot states. These launch arguments are
//  intentionally ignored outside DEBUG builds.
//

import Foundation

enum ScreenshotScenario: String {
    case vowels
    case vowelsBlurred = "vowels-blurred"
    case vowelsFiltered = "vowels-filtered"
    case consonantDetails = "consonant-details"
    case consonantDetailsHidden = "consonant-details-hidden"
    case vowelDetails = "vowel-details"
    case clusterDetails = "cluster-details"
    case toneMarkDetails = "tone-mark-details"
    case toneRuleDetails = "tone-rule-details"
    case tones
    case flashcard
    case flashcardCompleted = "flashcard-completed"
    case progress

    static var current: ScreenshotScenario? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard let flagIndex = arguments.firstIndex(of: "-screenshotScenario") else {
            return nil
        }
        let valueIndex = arguments.index(after: flagIndex)
        guard arguments.indices.contains(valueIndex) else { return nil }
        return ScreenshotScenario(rawValue: arguments[valueIndex])
        #else
        return nil
        #endif
    }

    var initialTab: AppTab {
        switch self {
        case .flashcard, .flashcardCompleted, .progress:
            return .flashcards
        default:
            return .reference
        }
    }

    var referenceType: CheatsheetEntryType {
        switch self {
        case .vowels, .vowelsBlurred, .vowelsFiltered, .vowelDetails:
            return .vowels
        case .tones, .toneMarkDetails, .toneRuleDetails:
            return .tones
        case .clusterDetails:
            return .clusters
        default:
            return .consonants
        }
    }

    static var initialPracticeMode: PracticeMode {
        let mode = PracticeMode()
        if current == .vowelsBlurred || current == .consonantDetailsHidden {
            mode.isActive = true
        }
        return mode
    }

    static var initialSearchText: String {
        current == .vowelsFiltered ? "ั" : ""
    }

    static var initialReferenceSelection: ReferenceSelection {
        let selection = ReferenceSelection()
        if let item = current?.referenceItem {
            selection.showDetails(item)
        }
        return selection
    }

    private var referenceItem: ReferenceItem? {
        switch self {
        case .consonantDetails, .consonantDetailsHidden:
            return .consonant("ค")
        case .vowelDetails:
            return .vowel(id: "a", variant: .shortClosed, text: "กั-")
        case .clusterDetails:
            return .cluster("กร:initial")
        case .toneMarkDetails:
            return .toneMark(id: "่", soundKey: "ค่า")
        case .toneRuleDetails:
            return .toneRule("Low-Short-Dead/None")
        default:
            return nil
        }
    }
}
