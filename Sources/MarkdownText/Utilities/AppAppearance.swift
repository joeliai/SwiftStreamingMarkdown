//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import UIKit

/// Appearance representation used to select
/// the precomputed light/dark citation preview image.
enum AppAppearance {
  case light
  case dark

  @WithLock
  static var current: AppAppearance = .dark

  var platformType: UIUserInterfaceStyle {
    switch self {
    case .dark: return UIUserInterfaceStyle.dark
    case .light: return UIUserInterfaceStyle.light
    }
  }

  static func update(style: UIUserInterfaceStyle) {
    $current.mutate { value in
      value = switch style {
      case .dark:
          .dark
      default:
          .light
      }
    }
  }

}
