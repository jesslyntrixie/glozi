//
//  DictionaryCardViewController.swift
//  glozi
//

import UIKit

/// The answer to a tap: one word, its pinyin, its meanings, and what its
/// characters mean on their own.
///
/// Presented as a sheet rather than invented chrome, so it behaves the way
/// every other sheet on the phone does: drag to resize, swipe down to dismiss,
/// and the page behind stays live and undimmed.
final class DictionaryCardViewController: UIViewController {

    static let detentHeight: CGFloat = 320

    private let scrollView = UIScrollView()
    private let stack = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground

        stack.axis = .vertical
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(stack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
            stack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -20),
        ])
    }

    // MARK: - Content

    /// Rebuilt rather than mutated, because the number of rows changes with
    /// every word and a card is cheap to build.
    func show(match: WordMatch, breakdown: [DictionaryEntry]) {
        loadViewIfNeeded()
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        stack.addArrangedSubview(headwordLabel(match.headword))

        if let entry = match.entries.first {
            stack.addArrangedSubview(pinyinLabel(entry.pinyin))
        } else {
            stack.addArrangedSubview(secondaryLabel("Not in the dictionary."))
        }

        stack.setCustomSpacing(14, after: stack.arrangedSubviews.last!)

        // Several entries can share one headword: 的 is both de and dī.
        for (offset, entry) in match.entries.enumerated() {
            if offset > 0 {
                stack.addArrangedSubview(separator())
                stack.addArrangedSubview(pinyinLabel(entry.pinyin))
            }
            for (number, definition) in entry.definitions.enumerated() {
                stack.addArrangedSubview(definitionLabel("\(number + 1). \(definition)"))
            }
        }

        // Character breakdown. Half of why Chinese is learnable is seeing the
        // word and its parts at the same time, so a multi-character word always
        // shows what its characters mean alone.
        if match.headword.count > 1 && !breakdown.isEmpty {
            stack.addArrangedSubview(separator())
            stack.addArrangedSubview(sectionLabel("Characters"))

            for entry in breakdown {
                stack.addArrangedSubview(
                    characterRow(entry.simplified, entry.pinyin, entry.definitions.first ?? ""))
            }
        }

        scrollView.setContentOffset(.zero, animated: false)
    }

    // MARK: - Rows

    private func headwordLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        // Hanzi need real size to be legible, and the reader is looking at a
        // character they could not read a moment ago.
        label.font = .systemFont(ofSize: 44, weight: .regular)
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        return label
    }

    private func pinyinLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .preferredFont(forTextStyle: .title3)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        return label
    }

    private func definitionLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        return label
    }

    private func secondaryLabel(_ text: String) -> UILabel {
        let label = definitionLabel(text)
        label.textColor = .secondaryLabel
        return label
    }

    private func sectionLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .preferredFont(forTextStyle: .footnote)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .secondaryLabel
        return label
    }

    private func characterRow(_ character: String, _ pinyin: String, _ meaning: String) -> UIView {
        let hanzi = UILabel()
        hanzi.text = character
        hanzi.font = .systemFont(ofSize: 26)
        hanzi.setContentHuggingPriority(.required, for: .horizontal)

        let reading = UILabel()
        reading.text = pinyin
        reading.font = .preferredFont(forTextStyle: .subheadline)
        reading.adjustsFontForContentSizeCategory = true
        reading.textColor = .secondaryLabel
        reading.setContentHuggingPriority(.required, for: .horizontal)

        let gloss = UILabel()
        gloss.text = meaning
        gloss.font = .preferredFont(forTextStyle: .subheadline)
        gloss.adjustsFontForContentSizeCategory = true
        gloss.numberOfLines = 2

        let row = UIStackView(arrangedSubviews: [hanzi, reading, gloss])
        row.axis = .horizontal
        row.alignment = .firstBaseline
        row.spacing = 10
        return row
    }

    private func separator() -> UIView {
        let line = UIView()
        line.backgroundColor = .separator
        line.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale).isActive = true
        return line
    }
}
