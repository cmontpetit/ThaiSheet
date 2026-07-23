//
//  ReferenceDetailSheets.swift
//  ThaiSheet
//

import SwiftUI

// Reusable reference detail sheets, one per domain type. Each reads the audio,
// learning, and voice-override stores from the environment and assembles a
// `ReferenceItemSheet`, so the Reference tab rows and the Flashcard cards present
// an identical sheet from a single source. Pass `onPractice: nil` (the default)
// when presenting from a flashcard — the Practice action would circularly
// re-enter the same quiz. (The cluster equivalent lives in ClusterViews.swift.)

struct ConsonantDetailSheet: View {
    let consonant: Consonant
    var onPractice: (() -> Void)? = nil

    @Environment(\.audioPlayer) private var audioPlayer
    @Environment(\.learningModel) private var learningModel
    @Environment(\.thaiData) private var thaiData

    private var concealID: String { FlashcardType.consonant.cardId(for: consonant.id) }

    var body: some View {
        let hasSound = audioPlayer.hasSound(.consonant, key: consonant.character)
        let stage = learningModel.getProgress(forId: concealID).srsStage
        let voiceOverride = thaiData.voiceOverrideCatalogEntry(for: concealID)
            .map { ($0.descriptor, $0.canonicalPreview) }
        let wordAudios = consonant.sampleWord.map { sample in
            [
                ReferenceWordAudio(
                    role: .sampleWord,
                    word: sample,
                    hasSound: audioPlayer.hasSound(.sampleWord, key: sample.word),
                    onPlay: { audioPlayer.play(.sampleWord, key: sample.word) }
                )
            ]
        } ?? []
        ReferenceItemSheet(
            title: consonant.character,
            romanization: consonant.transcription,
            stage: stage,
            note: nil,
            primaryAudio: ReferencePrimaryAudio(
                role: .name,
                hasSound: hasSound,
                onPlay: { audioPlayer.play(.consonant, key: consonant.character, itemID: concealID) }
            ),
            wordAudios: wordAudios,
            onPractice: onPractice,
            voiceOverride: voiceOverride
        )
    }
}

struct VowelDetailSheet: View {
    let vowel: Vowel
    let formType: VowelFormVariant
    /// The specific form string (e.g. "กา-") shown as the sheet title.
    let text: String
    var onPractice: (() -> Void)? = nil

    @Environment(\.audioPlayer) private var audioPlayer
    @Environment(\.learningModel) private var learningModel
    @Environment(\.thaiData) private var thaiData

    private var concealID: String { FlashcardType.vowel.cardId(for: vowel.id) }

    private func referenceWordAudios() -> [ReferenceWordAudio] {
        vowelReferenceWordSources(
            for: vowel,
            duration: formType.duration,
            form: formType.form
        ).map { source in
            ReferenceWordAudio(
                role: source.role,
                word: source.word,
                hasSound: audioPlayer.hasSound(source.soundType, key: source.word.word),
                onPlay: {
                    audioPlayer.play(
                        source.soundType,
                        key: source.word.word,
                        itemID: source.usesItemVoiceOverride ? concealID : nil
                    )
                }
            )
        }
    }

    var body: some View {
        let pronunciation = vowel.pronunciation(for: formType.duration, form: formType.form)
        let stage = learningModel.getProgress(forId: FlashcardType.vowel.cardId(for: text)).srsStage
        let voiceOverride = thaiData.voiceOverrideCatalogEntry(for: concealID).map {
            entry -> (descriptor: VoiceOverrideDescriptor, preview: VoicePreviewTarget) in
            let target = pronunciation
                .map { VoicePreviewTarget(soundType: .vowel, playbackKey: $0.word) }
                ?? entry.canonicalPreview
            return (entry.descriptor, target)
        }
        ReferenceItemSheet(
            title: ThaiDisplay.placeholder(text),
            romanization: vowel.sound,
            stage: stage,
            note: vowel.note(for: formType.duration.rawValue, form: formType.form.rawValue),
            wordAudios: referenceWordAudios(),
            onPractice: onPractice,
            voiceOverride: voiceOverride
        )
    }
}

struct ToneMarkDetailSheet: View {
    let toneMark: ToneMark
    /// The class column's sound key (e.g. "ค่า"), identifying which entry to show.
    let soundKey: String
    var onPractice: (() -> Void)? = nil

    @Environment(\.audioPlayer) private var audioPlayer
    @Environment(\.learningModel) private var learningModel
    @Environment(\.thaiData) private var thaiData

    private var concealID: String { FlashcardType.toneMark.cardId(for: soundKey) }

    var body: some View {
        if let entry = toneMark.classEntries.first(where: { $0.soundKey == soundKey }),
           let tone = entry.tone {
            let hasSound = audioPlayer.hasSound(.toneMark, key: soundKey)
            let stage = learningModel.getProgress(forId: concealID).srsStage
            let voiceOverride = thaiData.voiceOverrideCatalogEntry(for: concealID)
                .map { ($0.descriptor, $0.canonicalPreview) }
            let wordAudios = toneMark.sampleWord(for: soundKey).map { sample in
                [
                    ReferenceWordAudio(
                        role: .sampleWord,
                        word: sample,
                        hasSound: audioPlayer.hasSound(.sampleWord, key: sample.word),
                        onPlay: { audioPlayer.play(.sampleWord, key: sample.word) }
                    )
                ]
            } ?? []
            ReferenceItemSheet(
                title: ThaiDisplay.placeholder(ToneMark.midConsonant + toneMark.mark),
                toneMarkContext: ToneMarkSheetContext(
                    mark: toneMark.mark,
                    consonantClass: entry.className,
                    tone: tone
                ),
                stage: stage,
                note: nil,
                primaryAudio: ReferencePrimaryAudio(
                    role: .tone,
                    hasSound: hasSound,
                    onPlay: { audioPlayer.play(.toneMark, key: soundKey, itemID: concealID) }
                ),
                wordAudios: wordAudios,
                onPractice: onPractice,
                voiceOverride: voiceOverride
            )
        }
    }
}

struct ToneRuleDetailSheet: View {
    let rule: ToneRule
    var onPractice: (() -> Void)? = nil

    @Environment(\.audioPlayer) private var audioPlayer
    @Environment(\.learningModel) private var learningModel
    @Environment(\.thaiData) private var thaiData

    private var concealID: String { FlashcardType.toneRule.cardId(for: rule.id) }

    private var ruleDisplay: String {
        let initial = String(localized: String.LocalizationValue(rule.initialConsonant), bundle: .appLanguage)
        let duration = String(localized: String.LocalizationValue(rule.vowelDuration), bundle: .appLanguage)
        let end = String(localized: String.LocalizationValue(rule.end), bundle: .appLanguage)
        return "\(initial) + \(duration) + \(end) = \(ThaiColors.toneName(rule.tone))"
    }

    private func referenceWord(from sample: ToneSample) -> ReferenceSampleWord {
        ReferenceSampleWord(word: sample.full, romanization: sample.romanization, meaning: sample.meaning)
    }

    private var referenceWordAudios: [ReferenceWordAudio] {
        var audios: [ReferenceWordAudio] = []
        if let primary = rule.primarySample {
            audios.append(
                ReferenceWordAudio(
                    role: .primaryExample,
                    word: referenceWord(from: primary),
                    hasSound: audioPlayer.hasSound(.toneRule, key: primary.full),
                    onPlay: { audioPlayer.play(.toneRule, key: primary.full, itemID: concealID) }
                )
            )
        }
        if let additional = rule.samples?.dropFirst().first {
            audios.append(
                ReferenceWordAudio(
                    role: .additionalExample,
                    word: referenceWord(from: additional),
                    hasSound: audioPlayer.hasSound(.toneRule, key: additional.full),
                    onPlay: { audioPlayer.play(.toneRule, key: additional.full) }
                )
            )
        }
        return audios
    }

    private var lowestStage: SRSStage {
        guard let samples = rule.samples else { return .new }
        let stages = samples.map { sample in
            let cardId = FlashcardType.toneRule.cardId(for: ToneRuleCard.key(rule: rule, sample: sample))
            return learningModel.getProgress(forId: cardId).srsStage
        }
        return stages.min() ?? .new
    }

    var body: some View {
        let voiceOverride = thaiData.voiceOverrideCatalogEntry(for: concealID)
            .map { ($0.descriptor, $0.canonicalPreview) }
        ReferenceItemSheet(
            title: ruleDisplay,
            toneRule: rule,
            usesCompactTitle: true,
            stage: lowestStage,
            note: rule.primarySample?.note?.localized,
            wordAudios: referenceWordAudios,
            onPractice: onPractice,
            voiceOverride: voiceOverride
        )
    }
}
