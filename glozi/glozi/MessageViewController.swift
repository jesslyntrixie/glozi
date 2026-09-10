//
//  MessageViewController.swift
//  glozi
//

import UIKit

/// A centred title and sentence. Used for the states a screen can be in when
/// it has nothing to show: empty, failed, nothing recognised.
final class MessageViewController: UIViewController {

    private let messageTitle: String
    private let message: String

    init(title: String, message: String) {
        self.messageTitle = title
        self.message = message
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("MessageViewController is created in code, not from a storyboard.")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let heading = UILabel()
        heading.text = messageTitle
        heading.font = .preferredFont(forTextStyle: .title2)
        heading.textAlignment = .center

        let body = UILabel()
        body.text = message
        body.font = .preferredFont(forTextStyle: .body)
        body.textColor = .secondaryLabel
        body.textAlignment = .center
        body.numberOfLines = 0

        // Both labels respect the reader's text size setting.
        [heading, body].forEach { $0.adjustsFontForContentSizeCategory = true }

        let stack = UIStackView(arrangedSubviews: [heading, body])
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
        ])
    }
}
