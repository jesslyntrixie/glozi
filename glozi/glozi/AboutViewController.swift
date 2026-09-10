//
//  AboutViewController.swift
//  glozi
//

import UIKit

/// Credit for the dictionary. CC BY-SA 4.0 requires this, so it is not a
/// polish item and does not get cut.
final class AboutViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground
        title = "About"

        let stack = UIStackView(arrangedSubviews: [
            label("Glozi", style: .largeTitle),
            label("From gloss and 字, the character. A reading companion for the Chinese you can see but cannot select.",
                  style: .body, secondary: true),

            spacer(),

            label("Dictionary", style: .headline),
            label("""
                  Definitions come from CC-CEDICT, a community maintained \
                  Chinese to English dictionary published by MDBG.

                  Used under the Creative Commons Attribution-ShareAlike 4.0 \
                  International licence.

                  cc-cedict.org
                  """, style: .footnote, secondary: true),

            spacer(),

            label("Made by", style: .headline),
            label("Jesslyn Trixie Edvilie\nApple Developer Academy, BINUS Tangerang, 2026",
                  style: .footnote, secondary: true),

            spacer(),

            label("Offline", style: .headline),
            label("Glozi does no networking at all. The dictionary is inside the app, so it works in airplane mode and sends nothing anywhere.",
                  style: .footnote, secondary: true),
        ])

        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false

        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(stack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -40),
            stack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -24),
        ])
    }

    private func label(_ text: String, style: UIFont.TextStyle, secondary: Bool = false) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .preferredFont(forTextStyle: style)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = secondary ? .secondaryLabel : .label
        label.numberOfLines = 0
        return label
    }

    private func spacer() -> UIView {
        let view = UIView()
        view.heightAnchor.constraint(equalToConstant: 16).isActive = true
        return view
    }
}
