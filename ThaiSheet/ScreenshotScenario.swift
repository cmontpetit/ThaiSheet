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
    case consonantDetails = "consonant-details"
    case tones
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
        case .flashcardCompleted, .progress:
            return .flashcards
        default:
            return .reference
        }
    }

    var referenceType: CheatsheetEntryType {
        switch self {
        case .vowels, .vowelsBlurred:
            return .vowels
        case .tones:
            return .tones
        default:
            return .consonants
        }
    }

    static var initialPracticeMode: PracticeMode {
        let mode = PracticeMode()
        if current == .vowelsBlurred {
            mode.isActive = true
        }
        return mode
    }
}
