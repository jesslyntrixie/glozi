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


//Cmd-U builds and runs all tests.
//Cmd-6 opens the Test navigator, the sidebar listing every test with a pass/fail marker.
//Cmd-Shift-Y toggles the debug console at the bottom, which is where print() output lands.
