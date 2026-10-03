//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import UIKit

/// Three dots that pulse in turn while a reply is on its way.
final class ThinkingIndicatorView: UIView {

  private static let dotDiameter: CGFloat = 8
  private static let dotSpacing: CGFloat = 6
  private static let pulseKey = "pulse"

  private let dots = (0..<3).map { _ in UIView() }

  override init(frame: CGRect) {
    super.init(frame: frame)
    for dot in dots {
      dot.backgroundColor = .secondaryLabel
      dot.layer.cornerRadius = Self.dotDiameter / 2
      addSubview(dot)
    }
    isAccessibilityElement = true
    accessibilityLabel = "Thinking"
    registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (view: ThinkingIndicatorView, _: UITraitCollection) in
      view.invalidateIntrinsicContentSize()
    }
  }

  required init?(coder: NSCoder) {
    nil
  }

  /// As tall as a line of body text, so that the first line of the reply that
  /// replaces it takes about the same space.
  override var intrinsicContentSize: CGSize {
    CGSize(
      width: 3 * Self.dotDiameter + 2 * Self.dotSpacing,
      height: UIFont.preferredFont(forTextStyle: .body, compatibleWith: traitCollection).lineHeight
    )
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    for (index, dot) in dots.enumerated() {
      dot.frame = CGRect(
        x: CGFloat(index) * (Self.dotDiameter + Self.dotSpacing),
        y: (bounds.height - Self.dotDiameter) / 2,
        width: Self.dotDiameter,
        height: Self.dotDiameter
      )
    }
  }

  override func didMoveToWindow() {
    super.didMoveToWindow()
    if window != nil {
      startAnimating()
    }
  }

  /// Starts the dots pulsing, unless they already are. A collection view
  /// strips a cell's animations when it reuses the cell, without moving it out
  /// of the window, so cells call this whenever they show the indicator.
  func startAnimating() {
    guard dots.contains(where: { $0.layer.animation(forKey: Self.pulseKey) == nil }) else { return }
    let startTime = CACurrentMediaTime()
    for (index, dot) in dots.enumerated() {
      let pulse = CABasicAnimation(keyPath: "opacity")
      pulse.fromValue = 0.25
      pulse.toValue = 1
      pulse.duration = 0.5
      pulse.autoreverses = true
      pulse.repeatCount = .infinity
      pulse.beginTime = startTime + Double(index) * 0.2
      pulse.fillMode = .backwards
      pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
      // Keeps pulsing after the app returns from the background.
      pulse.isRemovedOnCompletion = false
      dot.layer.add(pulse, forKey: Self.pulseKey)
    }
  }
}
