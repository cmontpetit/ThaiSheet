//
//  ToneRuleCard.swift
//  ThaiSheet
//

import Foundation

// Represents a single tone rule flashcard (one sample from a rule)
struct ToneRuleCard: Identifiable {
    let rule: ToneRule
    let sample: ToneSample
    let correctTone: String

    var id: String { Self.key(rule: rule, sample: sample) }

    /// Card key for a rule/sample pair, without constructing a full card
    static func key(rule: ToneRule, sample: ToneSample) -> String {
        "\(rule.id)-\(sample.full)"
    }

    static func allCards(from rules: [ToneRule]) -> [ToneRuleCard] {
        var cards: [ToneRuleCard] = []
        for rule in rules {
            guard let samples = rule.samples else { continue }
            for sample in samples {
                cards.append(ToneRuleCard(
                    rule: rule,
                    sample: sample,
                    correctTone: rule.tone
                ))
            }
        }
        return cards.shuffled()
    }
}
