//
//  QuestionCap.swift
//  ThaiSheet
//

import Foundation

/// A card question with a fixed answer set: the questions a narrowed deck can
/// give away. Sound, name, and tone answers are multiple choice drawn from the
/// full catalog, so a narrow deck never makes them trivial and they are not here.
enum CardQuestion: Hashable {
    case consonantClass
    case vowelDuration
    case vowelForm
    case toneMarkClass
    case toneRuleClass
    case toneRuleDuration
    case toneRuleEnding
    case clusterType
}

extension FlashcardItem {
    /// The fixed-answer questions this card asks, each with the answers its
    /// grading accepts (mirrors each view's `hasError`).
    var fixedAnswerQuestions: [CardQuestion: Set<String>] {
        switch self {
        case .consonant(let consonant, _):
            return [.consonantClass: [consonant.consonantClass.rawValue]]
        case .vowel(let card):
            var questions: [CardQuestion: Set<String>] = [:]
            if card.asksDuration {
                questions[.vowelDuration] = card.acceptsBothDurations
                    ? Set(VowelCard.VowelDuration.allCases.map(\.rawValue))
                    : [card.duration.rawValue]
            }
            if card.asksForm {
                questions[.vowelForm] = [card.form.rawValue]
            }
            return questions
        case .toneMark(let card):
            return [.toneMarkClass: [card.consonantClass.rawValue]]
        case .toneRule(let card):
            let rule = card.rule
            return [
                .toneRuleClass: [rule.initialConsonant],
                .toneRuleDuration: [rule.vowelDuration],
                // Grading folds "Dead/None" into "Dead" (ToneRuleCardState.hasError).
                .toneRuleEnding: [rule.end == "Dead/None" ? "Dead" : rule.end],
            ]
        case .cluster(let cluster):
            return [.clusterType: [cluster.type.rawValue]]
        }
    }
}

/// SRS advancement cap: a card is partially tested when the eligible deck gives
/// away the answer to a question the card asks. A question is given away when
/// one answer is accepted by every eligible card that asks it, and this card
/// accepts that answer too. The second condition matters for a card opened from
/// Reference outside the deck: a high-class consonant is not trivial just
/// because every eligible consonant is low class. A question no eligible card
/// asks gives nothing away.
enum QuestionCap {
    static func isCapped(_ card: FlashcardItem, deck: [FlashcardItem]) -> Bool {
        let deckQuestions = deck.map(\.fixedAnswerQuestions)
        for (question, accepted) in card.fixedAnswerQuestions {
            let groups = deckQuestions.compactMap { $0[question] }
            guard var common = groups.first else { continue }
            for answers in groups.dropFirst() {
                common.formIntersection(answers)
                if common.isEmpty { break }
            }
            if !common.isDisjoint(with: accepted) {
                return true
            }
        }
        return false
    }
}
