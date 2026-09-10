//
//  ReaderViewController.swift
//  glozi
//

import UIKit

/// The reading surface. Pinch to zoom, tap a character to resolve the word
/// it belongs to. Recognition runs once when the image arrives and is kept,
/// because it is slow and the answer never changes for a given image.
final class ReaderViewController: UIViewController {

    private let scrollView = UIScrollView()
    private let imageView = UIImageView()
    private let highlightView = UIView()
    private let hintView = UIView()           // one-time "this is tappable" flash
    private let spinner = UIActivityIndicatorView(style: .large)
    private let statusLabel = UILabel()

    private let image: UIImage
    private let recognizer: TextRecognizing
    private let lookup: WordLookup

    private var lines: [RecognizedLine] = []
    private var hasSetInitialZoom = false
    private var card: DictionaryCardViewController?

    /// Extra scrollable room at the bottom while the card is up. Without it the
    /// page cannot scroll past its own bottom edge, so a word in the last line
    /// can never be lifted clear of the sheet.
    private var cardInset: CGFloat = 0

    /// Breathing room between the page and the edges of the usable area, so a
    /// character at the very top is never flush against the navigation bar.
    private let imageMargin: CGFloat = 12

    init(image: UIImage, recognizer: TextRecognizing, lookup: WordLookup) {
        self.image = image
        self.recognizer = recognizer
        self.lookup = lookup
        super.init(nibName: nil, bundle: nil)
    }

    /// This project has no storyboards, so nothing will ever call this.
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("ReaderViewController is created in code, not from a storyboard.")
    }

    // MARK: - Setup

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground
        title = "Reader"

        imageView.image = image
        imageView.isUserInteractionEnabled = true

        scrollView.delegate = self
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never

        // The highlight sits inside the image view, so it scales and pans with
        // the artwork for free rather than needing repositioning on every zoom.
        highlightView.backgroundColor = UIColor.systemYellow.withAlphaComponent(0.30)
        highlightView.layer.borderColor = UIColor.systemYellow.cgColor
        highlightView.layer.borderWidth = 3
        highlightView.layer.cornerRadius = 4
        highlightView.isHidden = true
        highlightView.isUserInteractionEnabled = false

        hintView.isHidden = true
        hintView.isUserInteractionEnabled = false

        view.addSubview(scrollView)
        scrollView.addSubview(imageView)
        imageView.addSubview(hintView)
        imageView.addSubview(highlightView)

        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap))
        doubleTap.numberOfTapsRequired = 2
        imageView.addGestureRecognizer(doubleTap)

        let singleTap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        // Without this a double tap would also fire two lookups on the way past.
        // The cost is a short delay before a single tap resolves, which is the
        // same trade every photo viewer on the phone makes.
        singleTap.require(toFail: doubleTap)
        imageView.addGestureRecognizer(singleTap)

        setUpStatusViews()
        recognize()
    }

    private func setUpStatusViews() {
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.hidesWhenStopped = true

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = .preferredFont(forTextStyle: .body)   // respects Dynamic Type
        statusLabel.adjustsFontForContentSizeCategory = true
        statusLabel.textColor = .secondaryLabel
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.isHidden = true

        view.addSubview(spinner)
        view.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.topAnchor.constraint(equalTo: spinner.bottomAnchor, constant: 16),
            statusLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 32),
            statusLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -32),
        ])
    }

    // MARK: - Recognition

    /// Runs once, off the main thread, then never again for this image.
    private func recognize() {
        spinner.startAnimating()
        statusLabel.text = "Reading the page"
        statusLabel.isHidden = false

        guard let cgImage = image.cgImage else {
            finishRecognizing(with: [], message: "That image could not be read.")
            return
        }

        let recognizer = self.recognizer

        DispatchQueue.global(qos: .userInitiated).async {
            let lines = (try? recognizer.recognizedLines(in: cgImage)) ?? []

            DispatchQueue.main.async { [weak self] in
                self?.finishRecognizing(
                    with: lines,
                    message: lines.isEmpty ? "No Chinese found in this image." : nil)
            }
        }
    }

    private func finishRecognizing(with lines: [RecognizedLine], message: String?) {
        self.lines = lines

        spinner.stopAnimating()
        statusLabel.text = message
        statusLabel.isHidden = (message == nil)

        flashRecognisedText()
    }

    // MARK: - Tapping

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        // imageView's coordinate space is the image's own pixels, whatever the
        // zoom, which is exactly the space the recognised boxes convert into.
        let point = gesture.location(in: imageView)

        guard let hit = character(at: point) else {
            highlightView.isHidden = true
            return
        }

        guard let match = lookup.match(in: hit.line.text, tappedCharacterAt: hit.index) else {
            return
        }

        highlight(match.range, in: hit.line)
        showCard(for: match)
    }

    /// Double tap toggles between fitting the page and a comfortable reading
    /// zoom centred on what was tapped. Standard behaviour, so it needs no
    /// teaching, and it is the fastest way back out of a deep zoom.
    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        let isZoomedIn = scrollView.zoomScale > scrollView.minimumZoomScale * 1.05

        guard !isZoomedIn else {
            scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
            return
        }

        let target = min(scrollView.minimumZoomScale * 3, scrollView.maximumZoomScale)
        let point = gesture.location(in: imageView)

        // zoom(to:) takes a rectangle in the image's own coordinates and fits it
        // to the screen, so build the rectangle the target scale implies.
        let size = CGSize(width: scrollView.bounds.width / target,
                          height: scrollView.bounds.height / target)

        scrollView.zoom(to: CGRect(x: point.x - size.width / 2,
                                   y: point.y - size.height / 2,
                                   width: size.width,
                                   height: size.height),
                        animated: true)
    }

    // MARK: - The card

    private func showCard(for match: WordMatch) {
        let breakdown = lookup.characterBreakdown(of: match.headword)

        // If a card is already up, refill it rather than dismissing and
        // re-presenting, which would flicker on every tap.
        if let card, card.presentingViewController != nil {
            card.show(match: match, breakdown: breakdown)
            scrollHighlightClearOfCard()
            return
        }

        let card = DictionaryCardViewController()
        card.show(match: match, breakdown: breakdown)
        card.presentationController?.delegate = self
        self.card = card

        // Give the page somewhere to go before asking it to move.
        cardInset = DictionaryCardViewController.detentHeight
        centreImage()

        if let sheet = card.sheetPresentationController {
            let detent = UISheetPresentationController.Detent.custom(identifier: .cardHeight) { _ in
                DictionaryCardViewController.detentHeight
            }
            sheet.detents = [detent, .large()]

            // Leaving the small detent undimmed is what keeps the page behind
            // live: the reader can pan, zoom and tap the next word without
            // dismissing the card first.
            sheet.largestUndimmedDetentIdentifier = .cardHeight
            sheet.prefersGrabberVisible = true
            sheet.prefersScrollingExpandsWhenScrolledToEdge = false
            sheet.delegate = self
        }

        present(card, animated: true) { [weak self] in
            self?.scrollHighlightClearOfCard()
        }
    }

    /// The card must never cover the word it is describing. The highlight is
    /// scrolled into the strip of screen left above the sheet.
    private func scrollHighlightClearOfCard() {
        guard !highlightView.isHidden else { return }

        let scale = scrollView.zoomScale
        let highlightCentreY = highlightView.frame.midY * scale

        let visibleHeight = scrollView.bounds.height - DictionaryCardViewController.detentHeight
        guard visibleHeight > 0 else { return }

        let desired = highlightCentreY - visibleHeight / 2

        // The furthest the page can scroll is its own height plus whatever
        // padding sits below it, less one screen.
        let lowest = -scrollView.contentInset.top
        let highest = max(lowest,
                          scrollView.contentSize.height
                          + scrollView.contentInset.bottom
                          - scrollView.bounds.height)

        scrollView.setContentOffset(
            CGPoint(x: scrollView.contentOffset.x, y: min(max(desired, lowest), highest)),
            animated: true)
    }

    private func character(at point: CGPoint) -> (line: RecognizedLine, index: Int)? {
        for line in lines {
            for (index, character) in line.characters.enumerated() {
                guard let box = character.box else { continue }
                if pixelRect(box).contains(point) { return (line, index) }
            }
        }
        return nil
    }

    private func highlight(_ range: Range<Int>, in line: RecognizedLine) {
        let rects = range
            .compactMap { line.characters.indices.contains($0) ? line.characters[$0].box : nil }
            .map(pixelRect)

        guard let first = rects.first else {
            highlightView.isHidden = true
            return
        }

        highlightView.frame = rects.dropFirst().reduce(first) { $0.union($1) }
        highlightView.isHidden = false
        imageView.bringSubviewToFront(highlightView)
    }

    /// Vision reports normalised coordinates with the origin at the LOWER left.
    /// UIKit's origin is the UPPER left. Flipping y is what this line does, and
    /// getting it wrong puts every tap target in the wrong place.
    private func pixelRect(_ box: CGRect) -> CGRect {
        CGRect(x: box.minX * image.size.width,
               y: (1 - box.maxY) * image.size.height,
               width: box.width * image.size.width,
               height: box.height * image.size.height)
    }

    // MARK: - "This is tappable" hint

    /// Once, when recognition finishes, outline every word that was found and
    /// fade it out. Nothing on a photograph looks interactive, so without this
    /// a first-time reader has no reason to try tapping it. Live Text does the
    /// same thing for the same reason.
    ///
    /// Words rather than characters: the boxes are drawn per line span, which
    /// reads as "there is text here" rather than as a grid over the artwork.
    private func flashRecognisedText() {
        hintView.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
        hintView.frame = CGRect(origin: .zero, size: image.size)

        for line in lines where line.confidence >= VisionTextRecognizer.lowConfidence {
            let boxes = line.characters.compactMap(\.box).map(pixelRect)
            guard let first = boxes.first else { continue }

            let layer = CALayer()
            layer.frame = boxes.dropFirst().reduce(first) { $0.union($1) }.insetBy(dx: -3, dy: -3)
            layer.borderWidth = 2
            layer.borderColor = UIColor.systemYellow.withAlphaComponent(0.9).cgColor
            layer.backgroundColor = UIColor.systemYellow.withAlphaComponent(0.15).cgColor
            layer.cornerRadius = 4
            hintView.layer.addSublayer(layer)
        }

        guard hintView.layer.sublayers?.isEmpty == false else { return }

        hintView.alpha = 0
        hintView.isHidden = false

        // Fade in, hold, fade out. The hold is what makes it register as a hint
        // rather than a flicker.
        UIView.animate(withDuration: 0.25) {
            self.hintView.alpha = 1
        } completion: { _ in
            UIView.animate(withDuration: 0.6, delay: 0.9) {
                self.hintView.alpha = 0
            } completion: { _ in
                self.hintView.isHidden = true
            }
        }
    }

    // MARK: - Layout

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        scrollView.frame = view.bounds

        // The zoom LIMITS are safe to recalculate on every pass, so rotation and
        // safe area changes are handled.
        updateZoomLimits()

        // The image view's frame is NOT. While zooming, the scroll view owns that
        // frame and rewrites it, so setting it here on every pass fights the zoom
        // and corrupts the coordinate space taps are converted through. Set it
        // once, along with the starting zoom level.
        if !hasSetInitialZoom && view.bounds.width > 0 {
            imageView.frame = CGRect(origin: .zero, size: image.size)
            scrollView.contentSize = image.size
            scrollView.zoomScale = scrollView.minimumZoomScale
            hasSetInitialZoom = true
        }

        centreImage()
    }

    /// The screen area not covered by the navigation bar, the home indicator or
    /// the notch, minus a small margin. Everything below sizes against this
    /// rather than the full bounds, so no part of the page is ever stranded
    /// underneath a bar where it cannot be tapped.
    private var usableSize: CGSize {
        let safe = view.safeAreaInsets
        return CGSize(
            width: max(1, scrollView.bounds.width - safe.left - safe.right - imageMargin * 2),
            height: max(1, scrollView.bounds.height - safe.top - safe.bottom - imageMargin * 2))
    }

    /// Inside a zooming scroll view the image view is sized in the image's own
    /// pixel coordinates and the scroll view scales it. That is what keeps a tap
    /// convertible back to a pixel position at any zoom level.
    private func updateZoomLimits() {
        let available = usableSize

        // The scale at which the whole page just fits inside the usable area.
        let fitScale = min(available.width / image.size.width,
                           available.height / image.size.height)

        scrollView.minimumZoomScale = fitScale
        scrollView.maximumZoomScale = fitScale * 8   // enough to reach small text
    }

    /// Scroll views do not centre content smaller than themselves, so pad it.
    /// The safe area insets are added on top of the centring padding, which is
    /// what keeps the top of the page clear of the navigation bar.
    private func centreImage() {
        let safe = view.safeAreaInsets
        let available = usableSize
        let content = scrollView.contentSize

        let horizontal = max(0, (available.width - content.width) / 2)
        let vertical = max(0, (available.height - content.height) / 2)

        scrollView.contentInset = UIEdgeInsets(
            top: safe.top + imageMargin + vertical,
            left: safe.left + imageMargin + horizontal,
            bottom: safe.bottom + imageMargin + vertical + cardInset,
            right: safe.right + imageMargin + horizontal)
    }
}

extension ReaderViewController: UIAdaptivePresentationControllerDelegate {

    /// Fires when the reader swipes the card down. Take the extra room back and
    /// return the page to where it sits normally, so dismissing the card undoes
    /// everything showing it did.
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        card = nil
        cardInset = 0
        highlightView.isHidden = true

        UIView.animate(withDuration: 0.25) {
            self.centreImage()
            self.scrollView.setContentOffset(
                CGPoint(x: self.scrollView.contentOffset.x,
                        y: min(self.scrollView.contentOffset.y,
                               max(-self.scrollView.contentInset.top,
                                   self.scrollView.contentSize.height
                                   + self.scrollView.contentInset.bottom
                                   - self.scrollView.bounds.height))),
                animated: false)
        }
    }
}

extension ReaderViewController: UIScrollViewDelegate {

    /// The one method that makes a scroll view zoom at all.
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        imageView
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        centreImage()
    }
}


extension UISheetPresentationController.Detent.Identifier {
    /// The card's resting height. Named so it can be compared against, which is
    /// what keeps the page behind it undimmed at this size.
    static let cardHeight = Self("glozi.cardHeight")
}
