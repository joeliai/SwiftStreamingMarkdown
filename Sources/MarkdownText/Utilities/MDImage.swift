//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import UIKit

/// Image type used by the context-menu configuration. Resolves to `UIImage`.
public typealias MDImage = UIImage

extension MDImage {
  /// Creates an image from an SF Symbol name.
  public convenience init?(sfSymbol name: String) {
    self.init(systemName: name)
  }
}
