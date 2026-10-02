//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import UIKit

/// Renders a paragraph or heading block through a `ParagraphUIView`.
final class TextBlockView: UIView, MarkdownBlockView {

  enum Style {
    case paragraph
    case heading

    /// Paragraphs get a fixed extra line spacing; headings keep the font's.
    var lineSpacing: CGFloat? {
      switch self {
      case .paragraph: return 5
      case .heading: return nil
      }
    }
  }

  let paragraphView: ParagraphUIView
  private let style: Style

  /// Replaces the paragraph's generated accessibility label, e.g. with a
  /// list-item position label.
  var accessibilityLabelOverride: String? {
    get { paragraphView.accessibilityLabelOverride }
    set { paragraphView.accessibilityLabelOverride = newValue }
  }

  init(style: Style, context: BlockContext) {
    self.style = style
    self.paragraphView = ParagraphViewCache.shared.createOrReuseView()
    super.init(frame: .zero)
    paragraphView.accessibilityLabelOverride = nil
    if style == .heading {
      paragraphView.accessibilityTraits.insert(.header)
    } else {
      paragraphView.accessibilityTraits.remove(.header)
    }
    addSubview(paragraphView)

    if context.config.shouldAnimateText {
      alpha = 0
      UIView.animate(withDuration: ParagraphUIView.animationDuration) {
        self.alpha = 1
      }
    }
  }

  required init?(coder: NSCoder) {
    nil
  }

  func update(with renderable: MarkdownRenderable, context: BlockContext) {
    let contents: NSMutableAttributedString
    switch renderable {
    case .paragraph(_, let content), .heading(_, _, let content):
      contents = content
    default:
      return
    }
    let lineSpacing = style.lineSpacing
    if paragraphView.paragraphContents != contents || paragraphView.lineSpacing != lineSpacing {
      // Only animate appended words while the text is on screen.
      let animatedByWord = window != nil && context.config.shouldAnimateText
      paragraphView.setParagraphContents(contents, lineSpacing: lineSpacing, animatedByWord: animatedByWord)
      setNeedsLayout()
    }
    paragraphView.setTextContextMenu(context.config.resolvedTextContextMenu)
    paragraphView.setMarkdownController(context.controller)
  }

  func height(forWidth width: CGFloat) -> CGFloat {
    paragraphView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height
  }

  override func sizeThatFits(_ size: CGSize) -> CGSize {
    CGSize(width: size.width, height: height(forWidth: size.width))
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    paragraphView.frame = bounds
  }
}
