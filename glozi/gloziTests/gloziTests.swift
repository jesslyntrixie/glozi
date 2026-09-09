//
//  gloziTests.swift
//  gloziTests
//
//  Created by Jesslyn Trixie Edvilie on 06/09/26.
//

import Testing
import NaturalLanguage
import Foundation
@testable import glozi

@Test func findsAHeadword() throws {
    let url = try #require(Bundle.main.url(forResource: "glozi", withExtension: "sqlite"))
    let dictionary = try #require(DictionaryDatabase(url: url))

    let entries = dictionary.entries(for: "研究生")

    #expect(entries.count == 1)
    #expect(entries.first?.pinyin == "yán jiū shēng")
    #expect(entries.first?.definitions.first == "graduate student")
}

@Test func findsBothReadingsOfAHomograph() throws {
    let url = try #require(Bundle.main.url(forResource: "glozi", withExtension: "sqlite"))
    let dictionary = try #require(DictionaryDatabase(url: url))

    let pinyin = dictionary.entries(for: "的").map(\.pinyin)

    #expect(pinyin.contains("de"))
    #expect(pinyin.contains("dī"))
}

/// Not a real test. A probe: prints what Apple's tokenizer does with Chinese
/// so OD-14 is answered with output rather than assumption. Delete after recording.
@Test func appleTokenizesChinese() {
    let sentences = [
        "中国人民都希望",
        "研究生命起源",
        "这个人很好",
        "上海市长江大桥",
        "理所当然同盟军"
    ]

    let tokenizer = NLTokenizer(unit: .word)
    tokenizer.setLanguage(.simplifiedChinese)

    for sentence in sentences {
        tokenizer.string = sentence

        var tokens: [String] = []
        tokenizer.enumerateTokens(in: sentence.startIndex ..< sentence.endIndex) { range, _ in
            tokens.append(String(sentence[range]))
            return true   // false would stop early
        }

        print("\(sentence)  ->  \(tokens.joined(separator: " / "))")
    }
}

@Test func dictionaryShipsWithTheApp() {
    let url = Bundle.main.url(forResource: "glozi", withExtension: "sqlite")
    #expect(url != nil)
    print("Dictionary at: \(url?.path ?? "NOT FOUND")")
}


// MARK: - WordLookup

/// Both of these are needed by every WordLookup test, so they live in one place.
private func makeLookup() throws -> WordLookup {
    let url = try #require(Bundle.main.url(forResource: "glozi", withExtension: "sqlite"))
    let database = try #require(DictionaryDatabase(url: url))
    return WordLookup(dictionary: database)
}

/// One row of the table below. A named type rather than a bare tuple, so the
/// Test navigator shows a readable label for each case instead of "#3".
struct TapCase: Sendable, CustomStringConvertible {
    let line: String
    let tapIndex: Int
    let expected: String

    var description: String { "\(line) tap \(tapIndex) -> \(expected)" }
}

/// The behaviour the tokenizer decision bought us, case by case.
/// tapIndex is a zero-based character position in the line.
@Test(arguments: [
    TapCase(line: "中国人民都希望", tapIndex: 0, expected: "中国"),      // tap 中
    TapCase(line: "中国人民都希望", tapIndex: 1, expected: "中国"),      // tap 国, mid-word
    TapCase(line: "中国人民都希望", tapIndex: 2, expected: "人民"),      // tap 人
    TapCase(line: "中国人民都希望", tapIndex: 3, expected: "人民"),      // tap 民; greedy matching strands this one
    TapCase(line: "研究生命起源",   tapIndex: 3, expected: "生命"),      // tap 生
    TapCase(line: "上海市长江大桥", tapIndex: 3, expected: "长江"),      // tap 长; the classic ambiguity case
    TapCase(line: "这个人很好",     tapIndex: 1, expected: "这个"),      // tap 个; Pleco says 个人, we say 这个
    TapCase(line: "理所当然同盟军", tapIndex: 2, expected: "理所当然"),  // tap 当
    TapCase(line: "理所当然同盟军", tapIndex: 5, expected: "同盟军"),    // tap 盟
])
func resolvesTapToAWord(testCase: TapCase) throws {
    let lookup = try makeLookup()
    let match = try #require(lookup.match(in: testCase.line,
                                          tappedCharacterAt: testCase.tapIndex))
    #expect(match.headword == testCase.expected)
}

/// The invariant, not a specific answer: whatever is highlighted always
/// contains the character the reader actually touched.
@Test func highlightAlwaysCoversTheTap() throws {
    let lookup = try makeLookup()
    let line = "理所当然同盟军"

    for tapIndex in 0 ..< line.count {
        let match = try #require(lookup.match(in: line, tappedCharacterAt: tapIndex))
        #expect(match.range.contains(tapIndex),
                "tap \(tapIndex) fell outside \(match.headword)")
    }
}

/// A tap out of bounds is a caller bug, not a reader action. Returns nil.
@Test func rejectsAnIndexOutsideTheLine() throws {
    let lookup = try makeLookup()
    #expect(lookup.match(in: "中国", tappedCharacterAt: 5) == nil)
}

/// Every tap gets an answer, even where the dictionary has nothing,
/// because silence in response to a deliberate tap reads as a broken app.
@Test func fallsBackToTheBareCharacter() throws {
    let lookup = try makeLookup()
    let match = try #require(lookup.match(in: "嗯？", tappedCharacterAt: 1))
    #expect(match.range == 1 ..< 2)
}


//Cmd-U builds and runs all tests.
//Cmd-6 opens the Test navigator, the sidebar listing every test with a pass/fail marker.
//Cmd-Shift-Y toggles the debug console at the bottom, which is where print() output lands.
