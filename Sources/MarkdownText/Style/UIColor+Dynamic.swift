//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import UIKit

extension UIColor {
  /// Creates a dynamic color that resolves to different values in light and dark mode.
  public static func dynamic(light: UIColor, dark: UIColor) -> UIColor {
    UIColor { traitCollection in
      traitCollection.userInterfaceStyle == .dark ? dark : light
    }
  }

  /// Loads a named color from the package's asset catalog.
  static func moduleColor(_ name: String) -> UIColor {
    guard let color = UIColor(named: name, in: .module, compatibleWith: nil) else {
      assertionFailure("Missing bundled color asset \(name)")
      return .clear
    }
    return color
  }
}
