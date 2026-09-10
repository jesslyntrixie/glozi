//
//  TextRecognition.swift
//  glozi
//

import Foundation
import Vision
import CoreGraphics

/// One character on the page: what it is, and where it sits.
///
/// `box` is in Vision's coordinate space: normalised 0 to 1, origin at the
/// LOWER left. UIKit's origin is the upper left, so it must be flipped before
/// it is drawn or hit-tested. The flip belongs to the view layer, not here.
///
/// `box` is nil for characters Vision gives no geometry for, which in practice
/// means whitespace: it reports those as a degenerate rect at (0, 1) with zero
/// size. Keeping the character with a nil box rather than dropping it is what
/// lets an index into `characters` mean the same thing as an index into the
/// line's `text`. Dropping them would silently shift every index after a space.
struct RecognizedCharacter {
    let character: Character
    let box: CGRect?
}

/// One line of text as Vision read it.
struct RecognizedLine {
    let text: String
    let confidence: Float
    let box: CGRect
    let characters: [RecognizedCharacter]
}

/// Reading text out of an image.
///
/// A protocol rather than a concrete type so tests can supply fixed output
/// without a real image, and so this stays free of UIKit: the share extension
/// runs in its own process and must be able to use it.
protocol TextRecognizing {
    func recognizedLines(in image: CGImage) throws -> [RecognizedLine]
}

/// Vision's implementation.
///
/// Deliberately `.accurate` only. Measured on 10 Sep: `.fast` returned zero
/// observations on two of three real screenshots, and Latin gibberish on the
/// third. It is not a fallback. See docs/platform-findings.md, F2.
final class VisionTextRecognizer: TextRecognizing {

    /// Lines below this are usually mangled rather than merely uncertain.
    /// Measured: every line at 1.0 was well-formed Chinese, every line at 0.3
    /// was not a word. Nothing is dropped here, the caller decides what to do.
    static let lowConfidence: Float = 0.5

    func recognizedLines(in image: CGImage) throws -> [RecognizedLine] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["zh-Hans", "zh-Hant"]
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])

        return (request.results ?? []).compactMap { observation in
            guard let candidate = observation.topCandidates(1).first else { return nil }

            let text = candidate.string
            guard !text.isEmpty else { return nil }

            let characters = text.indices.map { index -> RecognizedCharacter in
                let range = index ..< text.index(after: index)
                let box = (try? candidate.boundingBox(for: range))?.boundingBox

                // A zero-size box is Vision saying "no geometry", not a real
                // rectangle at the origin. Treat it as absent.
                let usable = (box?.width ?? 0) > 0 && (box?.height ?? 0) > 0

                return RecognizedCharacter(character: text[index],
                                           box: usable ? box : nil)
            }

            return RecognizedLine(text: text,
                                  confidence: candidate.confidence,
                                  box: observation.boundingBox,
                                  characters: characters)
        }
    }
}
