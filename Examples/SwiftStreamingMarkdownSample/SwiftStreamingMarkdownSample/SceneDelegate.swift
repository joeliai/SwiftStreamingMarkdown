//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {

  var window: UIWindow?
  private var settingsObserver: NSObjectProtocol?

  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    guard let windowScene = scene as? UIWindowScene else { return }
    let window = UIWindow(windowScene: windowScene)
    window.rootViewController = UINavigationController(rootViewController: DemoListViewController())
    window.overrideUserInterfaceStyle = SampleSettings.shared.appearanceMode.userInterfaceStyle
    window.makeKeyAndVisible()
    self.window = window

    settingsObserver = NotificationCenter.default.addObserver(
      forName: SampleSettings.didChangeNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.window?.overrideUserInterfaceStyle = SampleSettings.shared.appearanceMode.userInterfaceStyle
    }
  }
}
