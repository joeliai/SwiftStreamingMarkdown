//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import UIKit

/// The shimmering placeholder shown while a block image is loading.
final class BlockImageLoadingView: UIView {

  static let height: CGFloat = 200
  private static let shimmerAnimationKey = "shimmer"

  private let shimmerMask = CAGradientLayer()

  override init(frame: CGRect) {
    super.init(frame: frame)
    backgroundColor = .quaternaryLabel
    layer.cornerRadius = 8
    layer.cornerCurve = .continuous
    isAccessibilityElement = false

    // A brighter band sweeps diagonally across a dimmed placeholder.
    shimmerMask.colors = [
      UIColor.black.withAlphaComponent(0.3).cgColor,
      UIColor.black.cgColor,
      UIColor.black.withAlphaComponent(0.3).cgColor
    ]
    shimmerMask.startPoint = CGPoint(x: 0, y: 0)
    shimmerMask.endPoint = CGPoint(x: 1, y: 1)
    shimmerMask.locations = [-0.3, -0.15, 0]
    layer.mask = shimmerMask
  }

  required init?(coder: NSCoder) {
    nil
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    shimmerMask.frame = bounds
  }

  override func didMoveToWindow() {
    super.didMoveToWindow()
    if window == nil {
      shimmerMask.removeAnimation(forKey: Self.shimmerAnimationKey)
    } else if shimmerMask.animation(forKey: Self.shimmerAnimationKey) == nil {
      let animation = CABasicAnimation(keyPath: "locations")
      animation.fromValue = [-0.3, -0.15, 0]
      animation.toValue = [1, 1.15, 1.3]
      animation.duration = 1.5
      animation.repeatCount = .infinity
      shimmerMask.add(animation, forKey: Self.shimmerAnimationKey)
    }
  }
}
