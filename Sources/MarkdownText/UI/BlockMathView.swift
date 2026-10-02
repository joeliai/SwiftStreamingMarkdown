//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import iosMath
import UIKit

/// Renders a display (block-level) LaTeX formula inside a horizontal scroll
/// view, so formulas wider than the screen can be scrolled.
final class BlockMathView: UIView, MarkdownBlockView {

  private let scrollView = UIScrollView()
  private let mathLabel = MTMathUILabel()
  private var cachedLabelSize: CGSize?

  init() {
    super.init(frame: .zero)
    scrollView.showsHorizontalScrollIndicator = false
    scrollView.showsVerticalScrollIndicator = false
    scrollView.alwaysBounceVertical = false
    addSubview(scrollView)

    mathLabel.displayErrorInline = false
    mathLabel.fontSize = Typography.base.mdFont.pointSize
    scrollView.addSubview(mathLabel)
  }

  required init?(coder: NSCoder) {
    nil
  }

  func update(with renderable: MarkdownRenderable, context: BlockContext) {
    guard case .latex(_, let latex) = renderable else { return }
    if mathLabel.textColor != context.config.paragraphStyle.textColor {
      mathLabel.textColor = context.config.paragraphStyle.textColor
    }
    if mathLabel.latex != latex {
      mathLabel.latex = latex
      cachedLabelSize = nil
      setNeedsLayout()
    }
  }

  func height(forWidth width: CGFloat) -> CGFloat {
    labelSize.height
  }

  override func sizeThatFits(_ size: CGSize) -> CGSize {
    CGSize(width: size.width, height: labelSize.height)
  }

  /// The formula's size. `MTMathUILabel` can clip short formulas by a point,
  /// so one extra point of height is added.
  private var labelSize: CGSize {
    if let cachedLabelSize {
      return cachedLabelSize
    }
    let fitted = mathLabel.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude))
    let size = CGSize(width: fitted.width.rounded(.up), height: fitted.height.rounded(.up) + 1)
    cachedLabelSize = size
    return size
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    scrollView.frame = bounds
    mathLabel.frame = CGRect(origin: .zero, size: labelSize)
    scrollView.contentSize = labelSize
  }

  override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
      mathLabel.setNeedsDisplay()
    }
  }
}
