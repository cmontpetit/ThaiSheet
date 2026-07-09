//
//  ThaiDisplay.swift
//  ThaiSheet
//

import Foundation

/// Display-only transforms for Thai reference text.
enum ThaiDisplay {
    /// Thai marks that attach above or below their base consonant.
    /// U+0E31 mai han akat, U+0E33 sara am (leading nikhahit renders above),
    /// U+0E34–U+0E3A vowels above/below, U+0E47–U+0E4E tone and other marks.
    private static let combiningMarks: Set<Unicode.Scalar> = {
        var set = Set<Unicode.Scalar>()
        set.insert(Unicode.Scalar(0x0E31)!)
        set.insert(Unicode.Scalar(0x0E33)!)
        for value in 0x0E34...0x0E3A { set.insert(Unicode.Scalar(value)!) }
        for value in 0x0E47...0x0E4E { set.insert(Unicode.Scalar(value)!) }
        return set
    }()

    private static let placeholderConsonant: Unicode.Scalar = "ก"
    private static let dottedCircle: Unicode.Scalar = "\u{25CC}"
    private static let hairSpace: Unicode.Scalar = "\u{200A}"

    /// Replaces the ก placeholder consonant in a vowel form with a dotted
    /// circle for display. The result is for rendering only — sound file
    /// keys, SRS ids, and search all use the raw ก-based form.
    ///
    /// When ก carries an above/below mark, ก becomes a hair space instead of
    /// an explicit U+25CC: the text engine then auto-inserts a single dotted
    /// circle under the orphaned mark, whereas an explicit U+25CC would get
    /// a second circle drawn next to it. The hair space also keeps the mark
    /// from attaching to a preposed vowel (เ แ โ); zero-width characters
    /// don't work because the shaper deletes them and glues the mark anyway.
    static func vowelPlaceholder(_ form: String) -> String {
        substitute(form) { next in
            next.map(combiningMarks.contains) == true ? hairSpace : dottedCircle
        }
    }

    /// Replaces each ก according to `replacement(nextScalar)`.
    private static func substitute(
        _ form: String,
        replacement: (Unicode.Scalar?) -> Unicode.Scalar
    ) -> String {
        var result = String.UnicodeScalarView()
        let scalars = Array(form.unicodeScalars)
        for (index, scalar) in scalars.enumerated() {
            if scalar == placeholderConsonant {
                let next = index + 1 < scalars.count ? scalars[index + 1] : nil
                result.append(replacement(next))
            } else {
                result.append(scalar)
            }
        }
        return String(result)
    }
}
