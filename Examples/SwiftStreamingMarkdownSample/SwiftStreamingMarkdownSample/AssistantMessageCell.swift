//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import SwiftStreamingMarkdown
import UIKit

/// An assistant reply: a leading bubble hosting a `DocumentView`. The cell's
/// height follows the document through Auto Layout.
final class AssistantMessageCell: UICollectionViewCell {

  private let bubble = UIView()
  private let documentView = DocumentView()

  override init(frame: CGRect) {
    super.init(frame: frame)
    bubble.backgroundColor = UIColor.secondaryLabel.withAlphaComponent(0.12)
    bubble.layer.cornerRadius = 18
    bubble.layer.cornerCurve = .continuous

    for view in [bubble, documentView] {
      view.translatesAutoresizingMaskIntoConstraints = false
    }
    contentView.addSubview(bubble)
    bubble.addSubview(documentView)

    // Fill the row up to 560 points, leaving at least 48 points of trailing space.
    let preferredWidth = bubble.widthAnchor.constraint(equalTo: contentView.widthAnchor, constant: -48)
    preferredWidth.priority = .defaultHigh
    NSLayoutConstraint.activate([
      bubble.topAnchor.constraint(equalTo: contentView.topAnchor),
      bubble.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
      bubble.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
      bubble.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -48),
      bubble.widthAnchor.constraint(lessThanOrEqualToConstant: 560),
      preferredWidth,

      documentView.topAnchor.constraint(equalTo: bubble.topAnchor, constant: 14),
      documentView.bottomAnchor.constraint(equalTo: bubble.bottomAnchor, constant: -14),
      documentView.leadingAnchor.constraint(equalTo: bubble.leadingAnchor, constant: 14),
      documentView.trailingAnchor.constraint(equalTo: bubble.trailingAnchor, constant: -14)
    ])
  }

  required init?(coder: NSCoder) {
    nil
  }

  override func prepareForReuse() {
    super.prepareForReuse()
    // Block ids are positional, so drop the previous message's blocks.
    documentView.prepareForReuse()
  }

  func configure(document: RenderableDocument, config: MarkdownRenderConfig) {
    documentView.config = config
    documentView.renderableDocument = document
  }
}
