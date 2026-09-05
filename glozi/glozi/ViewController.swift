//
//  ViewController.swift
//  glozi
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // systemBackground adapts to light and dark mode on its own.
        view.backgroundColor = .systemBackground
        title = "Glozi"

        // Temporary proof that the window was built correctly. Delete once real UI exists.
        let label = UILabel()
        label.text = "汉"
        label.font = .systemFont(ofSize: 72, weight: .light)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
}
