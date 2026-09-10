# Glozi: platform findings

Measured, not assumed. Every claim here came from code that ran on this project.
Raw output is in the commit history; the spikes that produced it were deliberately
throwaway.

---

## F1. Apple's tokenizer segments Chinese correctly

**Question (OD-14, issue #4).** Does the platform tokenizer segment Chinese usefully,
or does word matching have to be written by hand?

**Method.** `NLTokenizer(unit: .word)` with `setLanguage(.simplifiedChinese)`, fed five
sentences chosen because they are hard: each has a competing reading that a naive
matcher gets wrong.

| Sentence | NLTokenizer | Greedy longest-match |
|---|---|---|
| 中国人民都希望 | 中国 / 人民 / 都 / 希望 | 中国人 / 民 / 都 / 希望 |
| 研究生命起源 | 研究 / 生命 / 起源 | 研究生 / 命 / 起源 |
| 这个人很好 | 这个 / 人 / 很 / 好 | 这个 / 人 / 很 / 好 |
| 上海市长江大桥 | 上海市 / 长江 / 大桥 | 上海市长 / 江 / 大桥 |
| 理所当然同盟军 | 理所当然 / 同盟军 | 理所当然 / 同盟军 |

Correct on all five, including 上海市长江大桥, the standard ambiguity example in
Chinese NLP, where 上海市长 / 江大桥 (Shanghai's mayor, Jiang Daqiao) is equally
grammatical. It picked the bridge.

**Finding.** iOS ships a competent Chinese word segmenter, offline, in four lines of
code. It is not widely known that it does.

**Decision.** Adopted as the primary way to find word boundaries.

**Reasoning.** Word boundaries in Chinese are a property of the sentence, not of the
character. Any rule that looks only at a few characters either side of a tap discards
the information that decides the answer.

This overturned a prior plan. Research notes inherited into this project had
reverse-engineered Pleco's tap behaviour into a three-step rule and argued for it. That
rule is a description of what Pleco does, not evidence that Pleco is right. On its own
flagship example, 中国人民 tapped on 国, it yields 国人 (compatriots, literary), a word
that is not in the sentence. The tokenizer yields 中国, which is.

**What was kept from the Pleco rule.** When the tokenizer's span is not a CC-CEDICT
headword, shrink to the longest piece of that span which is in the dictionary and still
covers the tapped character, then fall back to the single character. The highlight
therefore always contains the character the reader touched.

**What was discarded.** Pleco's one-character-backward step. It existed to correct
finger aiming error, because Pleco matches strictly forward and a tap on the second
character of a word would otherwise return nothing. The tokenizer returns the whole
word whichever character inside it is tapped, so there is no aiming error left to
correct.

---

## F2. The documented per-character bounding box limitation does not apply to Chinese

**Question (issue #3).** `VNRecognizedText.boundingBox(for:)` is documented to give
per-character geometry only at `recognitionLevel = .fast`. At `.accurate` it returns
the enclosing word's box for every character in that word, confirmed by Apple DTS on
the developer forums as intended behaviour rather than a bug. `.accurate` is the level
that actually reads stylised lettering. If it returns one box per line of Chinese,
character-level tapping is impossible and each line box has to be subdivided
arithmetically instead.

**Method.** `VNRecognizeTextRequest` at both levels, languages `zh-Hans` and `zh-Hant`,
against three real screenshots: a dense manhua platform interface, a second interface
capture, and a page of manga speech bubbles. For every recognised line, count how many
*distinct* character boxes come back.

**Result at `.accurate`.** Distinct box count equals character count on essentially
every line.

```
"我四点半"   characters 4, boxes returned 4, DISTINCT 4
  我  x 0.389  w 0.073
  四  x 0.461  w 0.072
  点  x 0.534  w 0.072
  半  x 0.606  w 0.063
```

Sequential, non-overlapping, tiling the line. Genuine per-character geometry.

**Why.** The limitation is real, and it is about words. Chinese is written without
spaces, so Vision treats each character as its own word, and the word box and the
character box are the same rectangle. The documented behaviour and the needed behaviour
coincide.

**The only exception is whitespace.** Space characters return a degenerate box,
`x 0.000 y 1.000 w 0.000 h 0.000`. Every line where distinct count fell below character
count contained a space. Consequence for implementation: zero-size boxes must be
skipped during hit-testing, or a tap near one corner of the image will select a space.

**Result at `.fast`.** Not a fallback. It is unusable.

| Image | `.accurate` | `.fast` |
|---|---|---|
| spike1, dense interface | 52 lines | 15 lines, Latin gibberish (`"£ * APITts F,ÉJI knIFJ"`) |
| spike2, interface capture | 3 lines | **0 observations** |
| spike3, manga bubbles | 8 lines, all confidence 1.00 | **0 observations** |

`.fast` found no text at all in two of three images. The tradeoff described in the
research notes does not exist: `.accurate` is better at reading *and* provides the
geometry.

**Decision.** `.accurate` only. The `.fast` code path is deleted rather than kept as a
fallback.

---

## F3. Confidence predicts correctness, and is usable as a filter

Every line returned at confidence 1.00 was well-formed Chinese. Lines at 0.30 were
mangled: 供看原创覆大康, 我哉相躏你的合浣, 保岩！. These are not words. They are the
recogniser guessing at small, stylised, low-contrast text.

This is a usable signal rather than noise. Options, undecided: make low-confidence text
untappable, or tappable but visibly marked as uncertain.

---

## F4. Tap target size is why zoom is not optional

Character box widths, as a fraction of image width, converted to pixels:

| Source | Box width | Pixels |
|---|---|---|
| spike3, manga speech bubbles (776px wide) | 0.05 to 0.078 | 40 to 60 |
| spike1, interface text (3008px wide) | 0.008 to 0.012 | 24 to 36 |

Apple's minimum touch target is 44pt. Manga lettering clears it. Interface text does
not. Pinch zoom is therefore a correctness requirement for a whole class of input, not
a convenience feature.

---

## F5. Coordinate spaces disagree, and it is not optional to remember

Vision reports normalised coordinates, 0 to 1, with the origin at the **lower** left.
UIKit's origin is the **upper** left. Every box must be flipped before it can be drawn
or hit-tested. Recorded here because it is the most common source of tap targets
landing in the wrong place.

---

## Not yet measured

- **Vertical text.** All three test images are horizontal. Manga is often set
  vertically. Untested, and it may not work at all.
- **Fragmentary OCR output.** F1 was measured on well-formed sentences. Segmentation of
  a fragment is confident nonsense. If OCR returns a broken line, the tokenizer's answer
  is unreliable and the discarded Pleco rule may need to come back as a fallback.
  Tracked as OD-14b.
- **spike2 returned only three fragments** where more text may be present. Whether that
  is a recognition failure or an image with little text has not been checked.
