//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import SwiftStreamingMarkdown
import UIKit

/// An assistant reply: a `DocumentView` that spans the cell's full width, on
/// the collection view's background. The cell's height follows the document
/// through Auto Layout.
final class AssistantMessageCell: UICollectionViewCell {

  private let documentView = DocumentView()

  override init(frame: CGRect) {
    super.init(frame: frame)
    documentView.translatesAutoresizingMaskIntoConstraints = false
    contentView.addSubview(documentView)

    // The vertical padding sets the reply apart from the messages around it.
    NSLayoutConstraint.activate([
      documentView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
      documentView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -14),
      documentView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
      documentView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor)
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
