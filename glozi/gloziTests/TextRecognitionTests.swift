//
//  TextRecognitionTests.swift
//  gloziTests
//

import Testing
import Foundation
import UIKit
@testable import glozi

/// Exists only so Bundle(for:) can find the test bundle, which is where the
/// spike images live. Bundle.main during a test is the host app.
private final class TestBundleToken {}

private func loadImage(_ name: String) throws -> CGImage {
    let bundle = Bundle(for: TestBundleToken.self)
    let url = try #require(bundle.url(forResource: name, withExtension: "png"))
    let image = try #require(UIImage(data: try Data(contentsOf: url)))
    return try #require(image.cgImage)
}

private func makeLookup() throws -> WordLookup {
    let url = try #require(Bundle.main.url(forResource: "glozi", withExtension: "sqlite"))
    return WordLookup(dictionary: try #require(DictionaryDatabase(url: url)))
}

// MARK: - Recognition

@Test func readsAPageOfMangaBubbles() throws {
    let lines = try VisionTextRecognizer().recognizedLines(in: try loadImage("spike3"))

    #expect(lines.count >= 6)

    // Measured on this image: every line came back at full confidence.
    #expect(lines.allSatisfy { $0.confidence >= VisionTextRecognizer.lowConfidence })

    let allText = lines.map(\.text).joined(separator: " ")
    #expect(allText.contains("哥哥"))
}

/// The invariant that everything downstream depends on: character N of
/// `characters` is character N of `text`. If a space ever silently dropped a
/// character, every tap after it in that line would resolve to the wrong word.
@Test func characterIndicesLineUpWithTheText() throws {
    let lines = try VisionTextRecognizer().recognizedLines(in: try loadImage("spike3"))

    for line in lines {
        #expect(line.characters.count == line.text.count)

        for (offset, character) in line.characters.enumerated() {
            let expected = line.text[line.text.index(line.text.startIndex, offsetBy: offset)]
            #expect(character.character == expected)
        }
    }
}

/// Hanzi always have geometry. Whitespace never does.
@Test func hanziHaveBoxesAndSpacesDoNot() throws {
    let lines = try VisionTextRecognizer().recognizedLines(in: try loadImage("spike3"))

    for line in lines {
        for character in line.characters where character.character.isWhitespace {
            #expect(character.box == nil)
        }

        let hanzi = line.characters.filter(isHanzi)
        #expect(hanzi.allSatisfy { $0.box != nil }, "a hanzi had no box in \(line.text)")
    }

    // And the image is not empty of hanzi overall, or the test proves nothing.
    #expect(lines.flatMap(\.characters).contains(where: isHanzi))
}

private func isHanzi(_ character: RecognizedCharacter) -> Bool {
    guard let scalar = character.character.unicodeScalars.first else { return false }
    return (0x4E00 ... 0x9FFF).contains(Int(scalar.value))
}

/// Boxes tile the line left to right rather than sitting on top of each other.
/// This is the finding that made character tapping possible at all.
@Test func boxesRunLeftToRightWithoutRepeating() throws {
    let lines = try VisionTextRecognizer().recognizedLines(in: try loadImage("spike3"))
    let line = try #require(lines.first { $0.text.count >= 4 })

    let boxes = line.characters.compactMap(\.box)
    #expect(boxes.count >= 4)

    for (earlier, later) in zip(boxes, boxes.dropFirst()) {
        #expect(later.minX > earlier.minX, "boxes are not advancing in \(line.text)")
    }

    // Distinct, not one box repeated for the whole line.
    #expect(Set(boxes.map(\.minX)).count == boxes.count)
}

// MARK: - The whole pipeline, minus the screen

/// Image in, word out. Everything except the view layer.
@Test func imageToWord() throws {
    let lines = try VisionTextRecognizer().recognizedLines(in: try loadImage("spike3"))
    let lookup = try makeLookup()

    // Find a line containing 知道 and tap its first character.
    let line = try #require(lines.first { $0.text.contains("知道") })
    let range = try #require(line.text.range(of: "知道"))
    let tapIndex = line.text.distance(from: line.text.startIndex, to: range.lowerBound)

    let match = try #require(lookup.match(in: line.text, tappedCharacterAt: tapIndex))

    #expect(match.headword == "知道")
    #expect(match.entries.first?.pinyin == "zhī dào")
    #expect(match.range.contains(tapIndex))

    print("\nPIPELINE: read \"\(line.text)\", tapped index \(tapIndex), got \(match.headword) \(match.entries.first?.pinyin ?? "")")
}
