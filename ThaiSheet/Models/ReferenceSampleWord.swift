//
//  ReferenceSampleWord.swift
//  ThaiSheet
//

import Foundation

struct ReferenceSampleWord: Codable {
    let word: String
    let romanization: String?
    let meaning: LocalizedText?

    init(word: String, romanization: String? = nil, meaning: LocalizedText? = nil) {
        self.word = word
        self.romanization = romanization
        self.meaning = meaning
    }

    var localizedMeaning: String? {
        meaning?.localized
    }
}

extension ReferenceSampleWord {
    static func fromConsonantName(_ name: String, transcription: String, meaning: LocalizedText? = nil) -> ReferenceSampleWord? {
        let parts = name.split(separator: " ", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return nil }
        let romanization = transcription.split(separator: " ", maxSplits: 1).dropFirst().first.map(String.init)
        return ReferenceSampleWord(word: parts[1], romanization: romanization, meaning: meaning)
    }
}
