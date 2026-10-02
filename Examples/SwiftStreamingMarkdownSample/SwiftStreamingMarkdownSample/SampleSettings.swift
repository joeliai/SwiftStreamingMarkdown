//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import UIKit

/// Sample-app preferences persisted in `UserDefaults`. Every change posts
/// `didChangeNotification` so open screens can refresh.
final class SampleSettings {

  static let shared = SampleSettings()
  static let didChangeNotification = Notification.Name("SampleSettingsDidChange")

  private enum Key {
    static let preferStreamedMarkdown = "preferStreamedMarkdown"
    static let appearanceMode = "appearanceMode"
    static let markdownTheme = "markdownTheme"
  }

  private let defaults = UserDefaults.standard

  var preferStreamedMarkdown: Bool {
    get { defaults.object(forKey: Key.preferStreamedMarkdown) as? Bool ?? true }
    set {
      defaults.set(newValue, forKey: Key.preferStreamedMarkdown)
      notifyChange()
    }
  }

  var appearanceMode: AppearanceMode {
    get { defaults.string(forKey: Key.appearanceMode).flatMap(AppearanceMode.init(rawValue:)) ?? .device }
    set {
      defaults.set(newValue.rawValue, forKey: Key.appearanceMode)
      notifyChange()
    }
  }

  var markdownTheme: SampleMarkdownTheme {
    get { defaults.string(forKey: Key.markdownTheme).flatMap(SampleMarkdownTheme.init(rawValue:)) ?? .automatic }
    set {
      defaults.set(newValue.rawValue, forKey: Key.markdownTheme)
      notifyChange()
    }
  }

  private func notifyChange() {
    NotificationCenter.default.post(name: Self.didChangeNotification, object: self)
  }
}

enum AppearanceMode: String, CaseIterable, Identifiable {
  case device
  case light
  case dark

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .device: return "Device"
    case .light: return "Light"
    case .dark: return "Dark"
    }
  }

  var userInterfaceStyle: UIUserInterfaceStyle {
    switch self {
    case .device: return .unspecified
    case .light: return .light
    case .dark: return .dark
    }
  }
}
