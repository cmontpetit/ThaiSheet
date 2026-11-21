/// Rimes and word boundaries for Arthit Juyaso’s *Read Thai in 10 Days*, 2nd ed.
/// See the Pronunciation guide (pp. xvi–xxi) and the vowel summary (pp. 138–139).
enum ReadThaiBookRomanization {
    static let diphthongs = ["ia": "ia", "eua": "uea", "ua": "ua"]

    private static let openVowels = [
        "a": "a", "aa": "aa", "i": "i", "ii": "ee", "u": "oo’", "uu": "oo",
        "e": "ay’", "ee": "ay", "ae": "air’", "aae": "air", "o": "o’", "oh": "oh",
        "aw": "or’", "aaw": "or", "eu": "ue’", "euu": "ue", "uh": "er’", "uuh": "er",
    ]

    // Day 3 uses u for a before a coda. Day 8 shows a’ in shortened แ forms and
    // or’ in shortened อ forms, though some examples omit the mark.
    private static let closedVowels = [
        "a": "u", "e": "e", "ae": "a’", "aae": "a", "o": "o",
        // Medial เ◌ิ- is always er: เงิน ngern, เหิม herm (pp. xvii, xx, 138).
        "uh": "er",
        // Closed ◌ุ keeps the guide's oo’: คุณ koo’n (p. xx), บุคคล bòo’k (p. 134).
        "u": "oo’",
    ]

    // For short counterparts absent from the guide, retain the long counterpart's
    // spelling and append the short marker. The rare เออว combines er and o.
    private static let yGlides = [
        "a": "ai", "aa": "aai", "u": "ui", "uu": "ooi", "aw": "oi’", "aaw": "oi",
        "oh": "oey", "uuh": "eui", "ua": "uai", "eua": "ueai",
    ]
    private static let wGlides = [
        "a": "ao", "aa": "aao", "i": "iw", "ia": "iao",
        "ae": "aeo’", "aae": "aeo", "e": "eo’", "ee": "eo", "uuh": "ero",
    ]

    static func rime(for syllable: ThaiSyllable, context: RomanizationContext) -> String {
        let nucleus = syllable.vowel
        let vowel = openVowels[nucleus] ?? diphthongs[nucleus] ?? nucleus
        switch syllable.glide {
        case "y": return yGlides[nucleus] ?? vowel + "i"
        case "o": return wGlides[nucleus] ?? vowel + "o"
        default: break
        }
        let variant: VowelFormVariant? = if case .vowelForm(let form) = context { form } else { nil }
        if !syllable.coda.isEmpty || variant?.form == .closed {
            return (closedVowels[nucleus] ?? vowel) + syllable.coda
        }
        // Open ◌ุ in a word is u: จุ ju (p. xx), จุฬา jùlaa (pp. 95, 143). The book
        // is not uniform: ดุ is dòo’ on p. 55, which this renders as dù. Vowel
        // labels keep the guide's oo’ (p. xix).
        if nucleus == "u", variant == nil, context != .vowelLabel {
            return "u"
        }
        if context == .shortOpenVowelExample || variant?.duration == .short, diphthongs[nucleus] != nil {
            return vowel + "’"
        }
        return vowel
    }

    /// The book commonly writes words solid. Keep a hyphen at vowel-led and
    /// ambiguous consonant boundaries, including ng + r (pp. xviii, xxi), and
    /// before dt and bp, which the book hyphenates in most words (ปฏัก bpà-dtùk,
    /// p. 141) though it prints some solid (ถูกต้อง tòokdtôrng). A default, not exact.
    static func separator(after previous: ThaiSyllable, before next: ThaiSyllable) -> String {
        if next.onset.isEmpty ||
            (next.onset.hasPrefix("ng") && previous.coda.isEmpty) ||
            (next.onset.hasPrefix("g") && previous.coda == "n") ||
            next.onset.hasPrefix("dt") || next.onset.hasPrefix("bp") ||
            (next.onset.hasPrefix("r") && previous.coda == "ng") {
            return "-"
        }
        return ""
    }
}
