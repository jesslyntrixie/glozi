//
//  WordLookup.swift
//  glozi
//
//  Created by Jesslyn Trixie Edvilie on 09/09/26.
//

import Foundation
import NaturalLanguage

/// What a tap resolved to.
struct WordMatch {
    let headword: String
    let range: Range<Int>            // character positions within the line
    let entries: [DictionaryEntry]   // empty only when even the character is unknown
}

/// Turns "the reader tapped character N of this line" into a dictionary answer.
final class WordLookup {

    private let dictionary: DictionaryDatabase
    private let tokenizer = NLTokenizer(unit: .word)

    init(dictionary: DictionaryDatabase) {
        self.dictionary = dictionary
        tokenizer.setLanguage(.simplifiedChinese)
    }

    func match(in line: String, tappedCharacterAt tapIndex: Int) -> WordMatch? {
        let characters = Array(line)
        guard characters.indices.contains(tapIndex) else { return nil }

        let token = tokenSpan(in: line, containing: tapIndex)

        // Longest piece of the token that is in the dictionary AND still
        // covers the tapped character. Longest first; earliest start wins ties.
        for length in stride(from: token.count, through: 1, by: -1) {
            for start in token.lowerBound ... (token.upperBound - length)
                where start <= tapIndex && tapIndex < start + length {

                let candidate = String(characters[start ..< start + length])
                let entries = dictionary.entries(for: candidate)

                if !entries.isEmpty {
                    return WordMatch(headword: candidate,
                                     range: start ..< start + length,
                                     entries: entries)
                }
            }
        }

        // Nothing matched at all. Show the bare character rather than nothing:
        // a reader who tapped deserves a response.
        return WordMatch(headword: String(characters[tapIndex]),
                         range: tapIndex ..< tapIndex + 1,
                         entries: [])
    }

    /// What each character of a word means on its own. Skips characters the
    /// dictionary has never heard of rather than showing an empty row.
    func characterBreakdown(of headword: String) -> [DictionaryEntry] {
        headword.compactMap { dictionary.entries(for: String($0)).first }
    }

    /// Where Apple thinks the word containing this character begins and ends.
    private func tokenSpan(in line: String, containing tapIndex: Int) -> Range<Int> {
        tokenizer.string = line

        let tapPosition = line.index(line.startIndex, offsetBy: tapIndex)
        let tokenRange = tokenizer.tokenRange(at: tapPosition)

        let start = line.distance(from: line.startIndex, to: tokenRange.lowerBound)
        let end   = line.distance(from: line.startIndex, to: tokenRange.upperBound)

        // Punctuation and whitespace produce an empty token. Fall back to the
        // single character so the caller always gets a usable span.
        guard start < end else { return tapIndex ..< tapIndex + 1 }

        return start ..< end
    }
}
