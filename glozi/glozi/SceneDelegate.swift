//
//  SceneDelegate.swift
//  glozi
//

import UIKit
import OSLog

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {

        // A window has to belong to a scene, so get the scene the system just handed us.
        guard let windowScene = (scene as? UIWindowScene) else { return }

        // Build the window ourselves. This is the job the storyboard used to do invisibly.
        let window = UIWindow(windowScene: windowScene)

        // The root view controller is the top of the view controller tree.
        // Wrapped in a navigation controller so we get a nav bar and push navigation later.
        //
        window.rootViewController = UINavigationController(rootViewController: makeRootViewController())

        self.window = window

        // Without this the window exists but never appears. Black screen, no error.
        window.makeKeyAndVisible()

        // Listen for screenshots arriving from the Action Button shortcut.
        // Set after the window is visible, so if one was already waiting it
        // has somewhere to go.
        Glozi.log.notice("scene connected, registering the inbox receiver")
        ScreenshotInbox.shared.receiver = { [weak self] image in
            self?.openReader(with: image)
        }
    }

    /// A screenshot arrived from the Shortcut. Whatever the reader was doing,
    /// the new screenshot wins: close any card or picker, go back to the start,
    /// and open the reader fresh. The back button then returns to the Library,
    /// the same as if the image had come from Photos.
    private func openReader(with image: UIImage) {
        Glozi.log.notice("openReader called")

        guard let navigation = window?.rootViewController as? UINavigationController,
              let library = navigation.viewControllers.first as? LibraryViewController else {
            Glozi.log.error("openReader: root is not the Library, so there is nothing to open")
            // The dictionary failed to open, so the root is the error message.
            // There is no reader to open, and the message already explains why.
            return
        }

        if navigation.presentedViewController != nil {
            navigation.dismiss(animated: false)
        }
        navigation.popToRootViewController(animated: false)
        library.open(image)
    }

    /// The dictionary is the one thing the app cannot run without, so build it
    /// here and show a plain message rather than crashing if it is missing.
    private func makeRootViewController() -> UIViewController {
        guard let url = Bundle.main.url(forResource: "glozi", withExtension: "sqlite"),
              let database = DictionaryDatabase(url: url) else {
            return MessageViewController(
                title: "Dictionary missing",
                message: "The bundled dictionary could not be opened, so lookups are unavailable.")
        }

        return LibraryViewController(recognizer: VisionTextRecognizer(),
                                     lookup: WordLookup(dictionary: database))
    }

    func sceneDidDisconnect(_ scene: UIScene) { }
    /// Also check here. Entering the foreground and becoming active are two
    /// different moments, and which one wins the race with the intent varies.
    func sceneDidBecomeActive(_ scene: UIScene) {
        ScreenshotInbox.shared.checkRepeatedly()
    }
    func sceneWillResignActive(_ scene: UIScene) { }
    /// "Open App" at the end of the Shortcut lands here when Glozi was already
    /// running in the background. Look for a screenshot the intent left behind.
    func sceneWillEnterForeground(_ scene: UIScene) {
        Glozi.log.notice("scene entering foreground")
        ScreenshotInbox.shared.checkRepeatedly()
    }
    func sceneDidEnterBackground(_ scene: UIScene) { }
}
