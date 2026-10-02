//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import UIKit

/// Rendering inputs shared by every block of a document.
struct BlockContext {
  let config: MarkdownRenderConfig
  weak var controller: MarkdownController?
}

/// A view that renders one `MarkdownRenderable` block with frame-based
/// layout. Containers size each block with `height(forWidth:)` and then assign
/// its frame.
protocol MarkdownBlockView: UIView {
  /// Applies `renderable`, which has the same id and kind as the renderable
  /// this view was created for.
  func update(with renderable: MarkdownRenderable, context: BlockContext)

  /// The height the block needs when laid out at `width`.
  func height(forWidth width: CGFloat) -> CGFloat
}

/// Implemented by views that cache measurements derived from their subviews,
/// so a size change deep in the tree can reach the document.
protocol MarkdownLayoutInvalidating: UIView {
  /// Drops cached measurements and schedules a layout pass.
  func invalidateMarkdownLayout()
}

extension UIView {
  /// Notifies every Markdown container above this view, up to and including
  /// the owning `DocumentView`, that its size may have changed.
  func setNeedsMarkdownLayout() {
    var current: UIView? = self
    while let view = current {
      (view as? MarkdownLayoutInvalidating)?.invalidateMarkdownLayout()
      if view is DocumentView {
        return
      }
      current = view.superview
    }
  }

  /// The view controller that manages the closest view in the superview chain,
  /// used to present modals such as the text selection sheet.
  var nearestViewController: UIViewController? {
    var responder: UIResponder? = self
    while let current = responder {
      if let viewController = current as? UIViewController {
        return viewController
      }
      responder = current.next
    }
    return nil
  }
}

extension MarkdownRenderable {
  /// The kind of view needed to render this renderable. A block view is only
  /// reused for a renderable of the same id and kind.
  enum Kind: Equatable {
    case paragraph
    case heading
    case latex
    case orderedList
    case unorderedList
    case codeBlock
    case table
    case thematicBreak
    case blockQuote
    case image
  }

  var kind: Kind {
    switch self {
    case .paragraph: return .paragraph
    case .heading: return .heading
    case .latex: return .latex
    case .orderedList: return .orderedList
    case .unorderedList: return .unorderedList
    case .codeBlock: return .codeBlock
    case .table: return .table
    case .thematicBreak: return .thematicBreak
    case .blockQuote: return .blockQuote
    case .image: return .image
    }
  }
}

/// Creates the view that renders `renderable`, already updated with it.
func makeBlockView(for renderable: MarkdownRenderable, context: BlockContext) -> MarkdownBlockView {
  let view: MarkdownBlockView
  switch renderable.kind {
  case .paragraph:
    view = TextBlockView(style: .paragraph, context: context)
  case .heading:
    view = TextBlockView(style: .heading, context: context)
  case .latex:
    view = BlockMathView()
  case .orderedList:
    view = ListBlockView(style: .ordered)
  case .unorderedList:
    view = ListBlockView(style: .unordered(nestedLevel: 0))
  case .codeBlock:
    view = CodeBlockView()
  case .table:
    view = TableView()
  case .thematicBreak:
    view = ThematicBreakView()
  case .blockQuote:
    view = BlockQuoteView()
  case .image:
    view = BlockImageView()
  }
  view.update(with: renderable, context: context)
  return view
}
