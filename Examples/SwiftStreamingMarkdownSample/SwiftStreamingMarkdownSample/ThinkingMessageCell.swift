//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import UIKit

/// An assistant reply that hasn't arrived yet, shown as a thinking indicator.
final class ThinkingMessageCell: UICollectionViewCell {

  private let indicator = ThinkingIndicatorView()

  override init(frame: CGRect) {
    super.init(frame: frame)
    indicator.translatesAutoresizingMaskIntoConstraints = false
    contentView.addSubview(indicator)
    NSLayoutConstraint.activate([
      indicator.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
      indicator.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -14),
      indicator.leadingAnchor.constraint(equalTo: contentView.leadingAnchor)
    ])
  }

  required init?(coder: NSCoder) {
    nil
  }

  func startAnimating() {
    indicator.startAnimating()
  }
}
