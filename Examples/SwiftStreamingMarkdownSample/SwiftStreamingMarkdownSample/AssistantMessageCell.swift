//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import Combine
import SwiftStreamingMarkdown
import UIKit

/// An assistant reply: a `DocumentView` that spans the cell's full width, on
/// the collection view's background. The cell observes the reply's view
/// model and updates the document view as the reply streams in, without
/// being reconfigured. The document view then invalidates the cell, whose
/// height follows the document through Auto Layout, and the collection view
/// resizes it.
final class AssistantMessageCell: UICollectionViewCell {

  private let documentView = DocumentView()
  private var replySubscription: AnyCancellable?

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
    replySubscription = nil
    // Block ids are positional, so drop the previous message's blocks.
    documentView.prepareForReuse()
  }

  func configure(reply: AssistantReplyViewModel, config: MarkdownRenderConfig) {
    documentView.config = config
    documentView.renderableDocument = reply.document
    // Later changes arrive on the next turn of the main run loop, outside of
    // any collection view update.
    replySubscription = reply.$document
      .dropFirst()
      .receive(on: DispatchQueue.main)
      .sink { [weak self] document in
        self?.documentView.renderableDocument = document
      }
  }
}
