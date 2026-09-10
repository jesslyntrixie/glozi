//
//  SceneDelegate.swift
//  glozi
//

import UIKit

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
    func sceneDidBecomeActive(_ scene: UIScene) { }
    func sceneWillResignActive(_ scene: UIScene) { }
    func sceneWillEnterForeground(_ scene: UIScene) { }
    func sceneDidEnterBackground(_ scene: UIScene) { }
}
