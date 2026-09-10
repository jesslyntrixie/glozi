//
//  OCRSpike.swift
//  gloziTests
//
//  THROWAWAY. Issue #3. Delete this file once the finding is recorded.
//
//  The question: VNRecognizedText.boundingBox(for:) is documented to give
//  per-character geometry only at recognitionLevel .fast. At .accurate it
//  returns the whole word's box for every character in that word. Nobody
//  knows what .accurate treats as a "word" in Chinese, where there are no
//  spaces. If it returns a whole line as one box, character-level tapping
//  is impossible and each line has to be subdivided arithmetically instead.
//
//  This prints, for both levels: what was read, and how many DISTINCT
//  character boxes each line produced. distinct == character count means
//  real per-character geometry. distinct == 1 means one box for the line.
//

import Testing
import Foundation
import Vision
import UIKit

/// Lowercase .png files sitting in the gloziTests folder.
/// Missing ones are skipped, so one, two or three all work.
private let spikeImageNames = ["spike1", "spike2", "spike3"]

/// Bundle.main is the host APP when tests run, and these images live in the
/// TEST bundle. Bundle(for:) needs a class to locate a bundle from, and this
/// empty one exists only to be that class. Standard trick, no other purpose.
private final class SpikeBundleToken {}

private var spikeBundle: Bundle { Bundle(for: SpikeBundleToken.self) }

private func describe(_ rect: CGRect) -> String {
    String(format: "x %.3f  y %.3f  w %.3f  h %.3f",
           rect.minX, rect.minY, rect.width, rect.height)
}

@Test func ocrGeometryOnRealScreenshots() throws {
    var analysed = 0

    for name in spikeImageNames {
        guard let url = spikeBundle.url(forResource: name, withExtension: "png") else {
            print("\n(no \(name).png in the bundle, skipping)")
            continue
        }

        analysed += 1
        try analyse(name: name, url: url)
    }

    #expect(analysed > 0, "No spike images found in the gloziTests folder.")
}

private func analyse(name: String, url: URL) throws {
    let image = try #require(UIImage(data: try Data(contentsOf: url)))
    let cgImage = try #require(image.cgImage)

    print("\n\n################ \(name).png ################")
    print("\(Int(image.size.width))x\(Int(image.size.height)) points, scale \(image.scale)")

    for level in [VNRequestTextRecognitionLevel.accurate, .fast] {
        let levelName = (level == .accurate) ? "accurate" : "fast"
        print("\n========== \(name) / recognitionLevel = \(levelName) ==========")

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = level
        request.recognitionLanguages = ["zh-Hans", "zh-Hant"]
        request.usesLanguageCorrection = true

        // Vision works in normalised coordinates, 0 to 1, origin at LOWER left.
        // UIKit's origin is upper left. That flip is a later problem; note it now.
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        let observations = request.results ?? []
        print("observations (lines): \(observations.count)")

        for observation in observations {
            guard let candidate = observation.topCandidates(1).first else { continue }

            let text = candidate.string
            print("\n  \"\(text)\"")
            print("    confidence \(String(format: "%.2f", candidate.confidence))")
            print("    line box   \(describe(observation.boundingBox))")

            // Ask for one box per character.
            var boxes: [CGRect] = []
            for index in text.indices {
                let range = index ..< text.index(after: index)
                if let rectangle = try? candidate.boundingBox(for: range) {
                    boxes.append(rectangle.boundingBox)
                }
            }

            // THE ANSWER. Two boxes count as the same if their x and width match.
            let distinct = Set(boxes.map { String(format: "%.4f|%.4f", $0.minX, $0.width) })
            print("    characters \(text.count), boxes returned \(boxes.count), DISTINCT \(distinct.count)")

            // First few, so the numbers are inspectable rather than just counted.
            for (character, box) in zip(text, boxes).prefix(5) {
                print("      \(character)  \(describe(box))")
            }
        }
    }
}
