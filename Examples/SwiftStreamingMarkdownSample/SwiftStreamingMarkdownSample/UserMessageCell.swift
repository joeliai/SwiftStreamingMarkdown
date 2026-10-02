//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import UIKit

/// A user message: a trailing blue bubble.
final class UserMessageCell: UICollectionViewCell {

  private let bubble = UIView()
  private let label = UILabel()

  override init(frame: CGRect) {
    super.init(frame: frame)
    bubble.backgroundColor = .systemBlue
    bubble.layer.cornerRadius = 18
    bubble.layer.cornerCurve = .continuous
    label.textColor = .white
    label.font = .preferredFont(forTextStyle: .body)
    label.adjustsFontForContentSizeCategory = true
    label.numberOfLines = 0

    for view in [bubble, label] {
      view.translatesAutoresizingMaskIntoConstraints = false
    }
    contentView.addSubview(bubble)
    bubble.addSubview(label)
    NSLayoutConstraint.activate([
      bubble.topAnchor.constraint(equalTo: contentView.topAnchor),
      bubble.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
      bubble.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
      bubble.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 48),

      label.topAnchor.constraint(equalTo: bubble.topAnchor, constant: 10),
      label.bottomAnchor.constraint(equalTo: bubble.bottomAnchor, constant: -10),
      label.leadingAnchor.constraint(equalTo: bubble.leadingAnchor, constant: 14),
      label.trailingAnchor.constraint(equalTo: bubble.trailingAnchor, constant: -14)
    ])
  }

  required init?(coder: NSCoder) {
    nil
  }

  func configure(text: String) {
    label.text = text
  }
}
