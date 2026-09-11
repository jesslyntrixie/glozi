//
//  LookUpScreenshotIntent.swift
//  glozi
//

import AppIntents
import UIKit
import OSLog
internal import UniformTypeIdentifiers

/// The Action Button way in.
///
/// An app cannot take a screenshot of another app. No API allows it. The
/// Shortcuts app can, with its own "Take Screenshot" action, because that
/// action belongs to the system. So the capture happens in a Shortcut and
/// this intent is the second step: it receives the image and opens the
/// reader with it.
///
///     Action Button -> Shortcut -> [Take Screenshot] -> [Look Up in Glozi] -> [Open App: Glozi]
///
/// Two jobs, two actions. This intent only RECEIVES the screenshot and puts it
/// somewhere safe. The system's own "Open App" action does the SHOWING. Asking
/// the intent to open the app itself did not work on a device (see
/// `supportedModes` below), and "Open App" is the one thing Shortcuts is
/// guaranteed to be allowed to do.
///
/// Any type that conforms to `AppIntent` in the app target shows up in the
/// Shortcuts app on its own. Nothing has to be registered.
///
/// `nonisolated` because this project makes everything main-actor by default,
/// and the `AppIntent` requirements (`title`, `description`) are not. Without
/// it the compiler refuses the conformance. `perform()` is put back on the main
/// actor by hand below, because it touches UIKit.
nonisolated struct LookUpScreenshotIntent: AppIntent {

    static let title: LocalizedStringResource = "Look Up in Glozi"

    static let description = IntentDescription(
        "Opens a screenshot in the Glozi reader so you can tap the word that stopped you.")

    /// Run in the background, quickly, and finish.
    ///
    /// Tried first: `openAppWhenRun = true` (deprecated from iOS 26), then
    /// `supportedModes = .foreground(.immediate)`. On a device, from the Action
    /// Button, both did the same thing: Glozi appeared in the Dynamic Island,
    /// the intent ran, and the app never came to the front. So the intent no
    /// longer tries. The next action in the Shortcut, "Open App", opens it.
    static let supportedModes: IntentModes = .background

    /// `supportedContentTypes: [.image]` tells Shortcuts this slot wants an
    /// image, so when it follows "Take Screenshot" the screenshot is filled in
    /// automatically. `IntentFile` is the raw file, handed across from the
    /// Shortcuts process as bytes.
    @Parameter(title: "Screenshot", supportedContentTypes: [.image])
    var screenshot: IntentFile

    /// How the action reads as a sentence in the Shortcuts editor.
    static var parameterSummary: some ParameterSummary {
        Summary("Look up \(\.$screenshot) in Glozi")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        Glozi.log.notice("intent perform() started, \(screenshot.data.count) bytes")

        // Check it really is an image now, while Shortcuts can still show an
        // error, rather than failing silently later in the reader.
        guard UIImage(data: screenshot.data)?.cgImage != nil else {
            throw LookUpScreenshotError.notAnImage
        }

        // Written to disk, not just kept in memory. The intent may run in a
        // background launch of the app that the system is free to end the
        // moment `perform()` returns, and "Open App" would then start a fresh
        // copy that never saw the image.
        try ScreenshotInbox.shared.deliver(screenshot.data)
        Glozi.log.notice("intent perform() finished, screenshot written")
        return .result()
    }
}

/// Shown by Shortcuts if the file it passed in is not something we can read.
nonisolated enum LookUpScreenshotError: Error, CustomLocalizedStringResourceConvertible {
    case notAnImage

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .notAnImage: "Glozi could not read that as an image."
        }
    }
}

/// The hand-off between the intent and the screens.
///
/// The intent runs, then a moment later "Open App" brings Glozi forward. Those
/// may even be two different launches of the app. So the intent never talks to
/// a view controller. It writes the screenshot to a file, and the screen side
/// checks for that file whenever it is ready to show something:
///
/// - when the window is first built (`receiver` is set),
/// - every time the app comes to the front (`SceneDelegate` calls `check()`),
/// - and straight away, if a receiver is already listening.
///
/// Whichever happens first opens the reader. The file is deleted as it is
/// read, so the same screenshot is never opened twice.
final class ScreenshotInbox {

    static let shared = ScreenshotInbox()

    /// The app's own temporary folder. Private to Glozi, and the system may
    /// clear it, which is fine for something meant to live for a few seconds.
    private let pendingFile = FileManager.default.temporaryDirectory
        .appendingPathComponent("pending-screenshot")

    /// Set by `SceneDelegate` once the window is built.
    var receiver: ((UIImage) -> Void)? {
        didSet { check() }
    }

    private init() { }

    func deliver(_ imageData: Data) throws {
        try imageData.write(to: pendingFile, options: .atomic)
        Glozi.log.notice("inbox: wrote \(imageData.count) bytes to \(self.pendingFile.path)")
        check()
    }

    /// Look now, and again a few times over the next couple of seconds.
    ///
    /// The intent and the screens can be in two different launches of the app,
    /// and Shortcuts gives no guarantee about which finishes first. If "Open App"
    /// runs before the intent writes the file, a single check on foreground finds
    /// nothing and nothing ever looks again. So the app keeps looking briefly
    /// rather than trusting the order of a Shortcut it does not control.
    func checkRepeatedly() {
        check()

        for delay in [0.25, 0.6, 1.2, 2.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.check()
            }
        }
    }

    /// If a screenshot is waiting and someone is listening, hand it over.
    func check() {
        let waiting = FileManager.default.fileExists(atPath: pendingFile.path)
        Glozi.log.notice("inbox: check, receiver \(self.receiver == nil ? "absent" : "present"), file \(waiting ? "waiting" : "none")")

        guard let receiver,
              let data = try? Data(contentsOf: pendingFile) else { return }

        try? FileManager.default.removeItem(at: pendingFile)

        guard let image = UIImage(data: data) else {
            Glozi.log.error("inbox: the pending file was not a readable image")
            return
        }

        Glozi.log.notice("inbox: handing the screenshot to the reader")
        receiver(image)
    }
}


/// One place to log from, so the whole Action Button path can be followed in
/// Console.app by filtering on the subsystem. Print statements are not enough
/// here: the intent can run in a background launch of the app with no debugger
/// attached, and print goes nowhere in that case.
nonisolated enum Glozi {
    static let log = Logger(subsystem: "com.glozi.app", category: "actionbutton")
}
