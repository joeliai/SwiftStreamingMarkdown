//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import UIKit

extension UIView {
  /// Adds `documentView` as a subview pinned to all four edges, so the host's
  /// Auto Layout size follows the document's intrinsic size.
  func embed(_ documentView: DocumentView) {
    documentView.translatesAutoresizingMaskIntoConstraints = false
    addSubview(documentView)
    NSLayoutConstraint.activate([
      documentView.topAnchor.constraint(equalTo: topAnchor),
      documentView.bottomAnchor.constraint(equalTo: bottomAnchor),
      documentView.leadingAnchor.constraint(equalTo: leadingAnchor),
      documentView.trailingAnchor.constraint(equalTo: trailingAnchor)
    ])
  }
}
