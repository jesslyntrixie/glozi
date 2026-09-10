//
//  LibraryViewController.swift
//  glozi
//

import UIKit
import PhotosUI

/// The way in. Pick a screenshot, open it in the reader.
///
/// `PHPickerViewController` runs in its own process and hands back only the
/// image the reader chose, so the app never asks for photo library permission
/// and never sees anything else. That is the right default for an app whose
/// whole argument is that it keeps to itself.
final class LibraryViewController: UIViewController {

    private let recognizer: TextRecognizing
    private let lookup: WordLookup

    private let heading = UILabel()
    private let body = UILabel()
    private let chooseButton = UIButton(configuration: .borderedProminent())
    private let sampleButton = UIButton(configuration: .plain())

    init(recognizer: TextRecognizing, lookup: WordLookup) {
        self.recognizer = recognizer
        self.lookup = lookup
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("LibraryViewController is created in code, not from a storyboard.")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground
        title = "Glozi"

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "About", style: .plain, target: self, action: #selector(showAbout))

        // 字, the character. The same mark as the app icon and the same 字 the
        // name comes from, so the screen, the icon and the name agree.
        heading.text = "字"
        heading.font = .systemFont(ofSize: 64, weight: .light)
        heading.textAlignment = .center

        // The first-run state, which is also the empty state. It says what the
        // app is for rather than just naming a button.
        body.text = "Open a screenshot with Chinese in it. Tap the character that stopped you and get that word, with pinyin and meaning."
        body.font = .preferredFont(forTextStyle: .body)
        body.adjustsFontForContentSizeCategory = true
        body.textColor = .secondaryLabel
        body.textAlignment = .center
        body.numberOfLines = 0

        var choose = chooseButton.configuration
        choose?.title = "Choose a screenshot"
        choose?.buttonSize = .large
        chooseButton.configuration = choose
        chooseButton.addTarget(self, action: #selector(chooseScreenshot), for: .touchUpInside)

        var sample = sampleButton.configuration
        sample?.title = "Try the sample page"
        sampleButton.configuration = sample
        sampleButton.addTarget(self, action: #selector(openSample), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [heading, body, chooseButton, sampleButton])
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 12
        stack.setCustomSpacing(28, after: body)
        stack.setCustomSpacing(4, after: chooseButton)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
        ])
    }

    // MARK: - Actions

    @objc private func chooseScreenshot() {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 1

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }

    @objc private func openSample() {
        guard let sample = UIImage(named: "sample") else { return }
        open(sample)
    }

    @objc private func showAbout() {
        navigationController?.pushViewController(AboutViewController(), animated: true)
    }

    private func open(_ image: UIImage) {
        let reader = ReaderViewController(image: image, recognizer: recognizer, lookup: lookup)
        navigationController?.pushViewController(reader, animated: true)
    }

    private func showCouldNotOpen() {
        let alert = UIAlertController(
            title: "Could not open that image",
            message: "Try another screenshot.",
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

extension LibraryViewController: PHPickerViewControllerDelegate {

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)

        guard let provider = results.first?.itemProvider,
              provider.canLoadObject(ofClass: UIImage.self) else { return }

        // Loading crosses a process boundary, so it is asynchronous and can fail.
        provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                guard let image = object as? UIImage else {
                    self.showCouldNotOpen()
                    return
                }
                self.open(image)
            }
        }
    }
}
