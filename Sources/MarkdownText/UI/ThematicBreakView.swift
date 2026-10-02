//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import UIKit

/// Renders a thematic break (`---`) as a horizontal rule.
final class ThematicBreakView: UIView, MarkdownBlockView {

  private static let verticalPadding: CGFloat = 8
  private static let ruleBandHeight: CGFloat = 4
  private static let ruleThickness: CGFloat = 1

  private let ruleView = UIView()

  init() {
    super.init(frame: .zero)
    addSubview(ruleView)
  }

  required init?(coder: NSCoder) {
    nil
  }

  func update(with renderable: MarkdownRenderable, context: BlockContext) {
    ruleView.backgroundColor = context.config.thematicBreakColor
  }

  func height(forWidth width: CGFloat) -> CGFloat {
    Self.verticalPadding * 2 + Self.ruleBandHeight
  }

  override func sizeThatFits(_ size: CGSize) -> CGSize {
    CGSize(width: size.width, height: height(forWidth: size.width))
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    let ruleY = Self.verticalPadding + (Self.ruleBandHeight - Self.ruleThickness) / 2
    ruleView.frame = CGRect(x: 0, y: ruleY, width: bounds.width, height: Self.ruleThickness)
  }
}
