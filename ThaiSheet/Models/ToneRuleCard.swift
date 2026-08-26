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

    /// Durable progress key: the rule's structural id plus the sample's stable
    /// id. Independent of the sample word, so correcting one keeps its progress.
    var id: String { Self.key(rule: rule, sample: sample) }

    /// Card key for a rule/sample pair, without constructing a full card
    static func key(rule: ToneRule, sample: ToneSample) -> String {
        "\(rule.id)#\(sample.id)"
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
        // Return the canonical source order (rules, then their samples).
        // Sequential mode relies on a stable order across launches; randomization
        // for smart selection lives in WanikaniStrategy, not here.
        return cards
    }
}
