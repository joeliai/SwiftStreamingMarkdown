//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import UIKit

/// Renders a block quote. Each nesting level draws a divider on its leading
/// edge and stacks its text and nested quotes beside it.
final class BlockQuoteView: UIView, MarkdownBlockView {

  private var rootNode: QuoteNodeView?
  private var quoteType: BlockQuoteType?
  private var textStyle: MarkdownRenderConfig.MarkdownTextStyle?

  func update(with renderable: MarkdownRenderable, context: BlockContext) {
    guard case .blockQuote(_, let item) = renderable else { return }
    let textStyle = context.config.blockQuoteStyle
    guard item.quoteType != quoteType || textStyle != self.textStyle else { return }
    quoteType = item.quoteType
    self.textStyle = textStyle

    rootNode?.removeFromSuperview()
    let rootNode = QuoteNodeView(quoteType: item.quoteType, textStyle: textStyle)
    addSubview(rootNode)
    self.rootNode = rootNode
    setNeedsLayout()
  }

  func height(forWidth width: CGFloat) -> CGFloat {
    rootNode?.height(forWidth: width) ?? 0
  }

  override func sizeThatFits(_ size: CGSize) -> CGSize {
    CGSize(width: size.width, height: height(forWidth: size.width))
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    rootNode?.frame = bounds
  }
}

/// One `BlockQuoteType` level: a divider when nested, beside its text or its
/// nested levels stacked vertically.
private final class QuoteNodeView: UIView {

  private static let dividerWidth: CGFloat = 3
  private static let dividerSpacing: CGFloat = 8
  private static let childSpacing: CGFloat = 12
  private static let verticalPadding: CGFloat = 4
  private static let textVerticalPadding: CGFloat = 4
  private static let trailingSpace: CGFloat = 8

  private enum Child {
    case text(UILabel)
    case nested(QuoteNodeView)
  }

  private let divider: UIView?
  private let children: [Child]

  init(quoteType: BlockQuoteType, textStyle: MarkdownRenderConfig.MarkdownTextStyle) {
    switch quoteType {
    case .text(let text):
      divider = nil
      let label = UILabel()
      label.numberOfLines = 0
      label.lineBreakMode = .byWordWrapping
      label.attributedText = NSAttributedString(
        string: text,
        attributes: textStyle.textFonts.textAttributes(color: textStyle.textColor)
      )
      children = [.text(label)]
    case .nested(let items):
      let divider = UIView()
      divider.backgroundColor = UIColor.Theme.Stroke.Muted.Muted300
      divider.layer.cornerRadius = Self.dividerWidth / 2
      divider.layer.cornerCurve = .continuous
      self.divider = divider
      children = items.map { .nested(QuoteNodeView(quoteType: $0, textStyle: textStyle)) }
    }
    super.init(frame: .zero)
    if let divider {
      addSubview(divider)
    }
    for child in children {
      switch child {
      case .text(let label): addSubview(label)
      case .nested(let node): addSubview(node)
      }
    }
  }

  required init?(coder: NSCoder) {
    nil
  }

  private var contentX: CGFloat {
    divider == nil ? 0 : Self.dividerWidth + Self.dividerSpacing
  }

  func height(forWidth width: CGFloat) -> CGFloat {
    layout(forWidth: width).height
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    let layout = layout(forWidth: bounds.width)
    divider?.frame = CGRect(x: 0, y: 0, width: Self.dividerWidth, height: bounds.height)
    for (child, frame) in zip(children, layout.frames) {
      switch child {
      case .text(let label): label.frame = frame
      case .nested(let node): node.frame = frame
      }
    }
  }

  private func layout(forWidth width: CGFloat) -> (frames: [CGRect], height: CGFloat) {
    let contentWidth = max(0, width - contentX)
    var frames: [CGRect] = []
    var y = Self.verticalPadding
    for (index, child) in children.enumerated() {
      if index > 0 {
        y += Self.childSpacing
      }
      switch child {
      case .text(let label):
        let textWidth = max(0, contentWidth - Self.trailingSpace)
        let textSize = label.sizeThatFits(CGSize(width: textWidth, height: .greatestFiniteMagnitude))
        let textHeight = textSize.height.rounded(.up)
        frames.append(CGRect(x: contentX, y: y + Self.textVerticalPadding, width: textWidth, height: textHeight))
        y += textHeight + Self.textVerticalPadding * 2
      case .nested(let node):
        let nodeHeight = node.height(forWidth: contentWidth)
        frames.append(CGRect(x: contentX, y: y, width: contentWidth, height: nodeHeight))
        y += nodeHeight
      }
    }
    return (frames, y + Self.verticalPadding)
  }
}

indirect enum BlockQuoteType: Equatable, Hashable {
  case text(String)
  case nested([BlockQuoteType])

  var isNested: Bool {
    switch self {
    case .text:
      false
    case .nested:
      true
    }
  }
}
