//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import UIKit

/// The placeholder shown when a block image fails to load.
final class BlockImageFailureView: UIView {

  static let minimumHeight: CGFloat = 44

  private let symbolView = UIImageView(
    image: UIImage(
      systemName: "photo.badge.exclamationmark",
      withConfiguration: UIImage.SymbolConfiguration(textStyle: .body, scale: .large)
    )
  )

  /// Tint for the symbol; defaults to the secondary label color.
  var symbolTintColor: UIColor = .secondaryLabel {
    didSet { symbolView.tintColor = symbolTintColor }
  }

  override init(frame: CGRect) {
    super.init(frame: frame)
    symbolView.tintColor = symbolTintColor
    symbolView.contentMode = .center
    addSubview(symbolView)
  }

  required init?(coder: NSCoder) {
    nil
  }

  var preferredHeight: CGFloat {
    max(Self.minimumHeight, symbolView.intrinsicContentSize.height)
  }

  override func sizeThatFits(_ size: CGSize) -> CGSize {
    CGSize(width: size.width, height: preferredHeight)
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    let symbolSize = symbolView.intrinsicContentSize
    symbolView.frame = CGRect(
      x: (bounds.width - symbolSize.width) / 2,
      y: (bounds.height - symbolSize.height) / 2,
      width: symbolSize.width,
      height: symbolSize.height
    )
  }
}
