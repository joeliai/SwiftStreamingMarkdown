//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import UIKit

/// A photo reply: an image loaded asynchronously from a URL. The image's size
/// isn't known until it loads, so a thinking indicator shows until then; the
/// image then appears across the cell's full width at its own aspect ratio.
final class ImageMessageCell: UICollectionViewCell {

  private let indicator = ThinkingIndicatorView()
  private let imageView = UIImageView()
  private let failureLabel = UILabel()
  private var aspectRatioConstraint: NSLayoutConstraint?
  private var url: URL?
  private var loadTask: Task<Void, Never>?

  override init(frame: CGRect) {
    super.init(frame: frame)
    imageView.contentMode = .scaleAspectFill
    imageView.clipsToBounds = true
    imageView.layer.cornerRadius = 16
    imageView.layer.cornerCurve = .continuous
    imageView.isAccessibilityElement = true
    imageView.accessibilityTraits = .image
    imageView.accessibilityIgnoresInvertColors = true

    failureLabel.text = "Couldn't load the image."
    failureLabel.font = .preferredFont(forTextStyle: .footnote)
    failureLabel.adjustsFontForContentSizeCategory = true
    failureLabel.textColor = .secondaryLabel

    // Only the view for the current state is visible: the indicator, the
    // image, or the failure message.
    let stack = UIStackView(arrangedSubviews: [indicator, imageView, failureLabel])
    stack.axis = .vertical
    stack.translatesAutoresizingMaskIntoConstraints = false
    contentView.addSubview(stack)
    // Below the required priority, so that it gives way to the estimated
    // height that a new cell starts with.
    let bottom = stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -14)
    bottom.priority = .required - 1
    NSLayoutConstraint.activate([
      stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
      bottom,
      stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
      stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor)
    ])
    showOnly(indicator)
  }

  required init?(coder: NSCoder) {
    nil
  }

  override func prepareForReuse() {
    super.prepareForReuse()
    loadTask?.cancel()
    loadTask = nil
    url = nil
    // Clear the previous photo, as if loading a different one.
    imageView.image = nil
    showOnly(indicator)
  }

  func configure(url: URL, description: String) {
    imageView.accessibilityLabel = description
    guard url != self.url else { return }
    self.url = url
    loadTask?.cancel()
    imageView.image = nil
    showOnly(indicator)
    loadTask = Task { [weak self] in
      let image = await Self.loadImage(from: url)
      guard !Task.isCancelled, let self, self.url == url else { return }
      if let image {
        self.show(image, animated: true)
      } else {
        self.showOnly(self.failureLabel)
      }
    }
  }

  private static func loadImage(from url: URL) async -> UIImage? {
    guard let data = try? await URLSession.shared.data(from: url).0,
          let image = UIImage(data: data) else {
      return nil
    }
    // Decode off the main thread, so that showing the image doesn't stall scrolling.
    return await image.byPreparingForDisplay() ?? image
  }

  private func show(_ image: UIImage, animated: Bool) {
    aspectRatioConstraint?.isActive = false
    aspectRatioConstraint = nil
    if image.size.width > 0 {
      // Below the required priority, so that it gives way to the stack view
      // while the image view is hidden.
      let aspectRatio = imageView.heightAnchor.constraint(
        equalTo: imageView.widthAnchor,
        multiplier: image.size.height / image.size.width
      )
      aspectRatio.priority = .required - 1
      aspectRatio.isActive = true
      aspectRatioConstraint = aspectRatio
    }
    imageView.image = image
    showOnly(imageView)
    if animated {
      imageView.alpha = 0
      UIView.animate(withDuration: 0.25) {
        self.imageView.alpha = 1
      }
    }
  }

  /// Shows `view` and hides the stack's other views, then asks the collection
  /// view to resize the cell to fit.
  private func showOnly(_ view: UIView) {
    for arrangedView in [indicator, imageView, failureLabel] {
      let isHidden = arrangedView !== view
      if arrangedView.isHidden != isHidden {
        arrangedView.isHidden = isHidden
      }
    }
    if view === indicator {
      indicator.startAnimating()
    }
    invalidateIntrinsicContentSize()
  }
}
