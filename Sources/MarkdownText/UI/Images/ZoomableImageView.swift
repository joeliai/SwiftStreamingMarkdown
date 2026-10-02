//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import UIKit

/// A zoomable, pannable image supporting pinch-to-zoom, double-tap zoom, and
/// swipe-down-to-dismiss. Used by the built-in fullscreen image viewer.
final class ZoomableImageView: UIView, UIScrollViewDelegate, UIGestureRecognizerDelegate {

  static let dismissVelocity: CGFloat = 1500
  static let minZoomScale: CGFloat = 1
  static let maxZoomScale: CGFloat = 4
  static let doubleTapZoomScale: CGFloat = 2

  var image: UIImage? {
    didSet {
      imageView.image = image
      scrollView.setZoomScale(Self.minZoomScale, animated: false)
      setNeedsLayout()
    }
  }

  /// Invoked when the image is flung downward while not zoomed in.
  var onSwipeToDismiss: (() -> Void)?

  private let scrollView = UIScrollView()
  private let imageView = UIImageView()
  private lazy var dismissPanRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handleDismissPan(_:)))

  override init(frame: CGRect) {
    super.init(frame: frame)
    scrollView.delegate = self
    scrollView.minimumZoomScale = Self.minZoomScale
    scrollView.maximumZoomScale = Self.maxZoomScale
    scrollView.showsHorizontalScrollIndicator = false
    scrollView.showsVerticalScrollIndicator = false
    scrollView.contentInsetAdjustmentBehavior = .never
    scrollView.decelerationRate = .fast
    addSubview(scrollView)

    imageView.contentMode = .scaleAspectFit
    scrollView.addSubview(imageView)

    let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
    doubleTap.numberOfTapsRequired = 2
    scrollView.addGestureRecognizer(doubleTap)

    dismissPanRecognizer.delegate = self
    addGestureRecognizer(dismissPanRecognizer)
  }

  required init?(coder: NSCoder) {
    nil
  }

  private var isZoomed: Bool {
    scrollView.zoomScale > Self.minZoomScale
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    guard scrollView.frame != bounds || !isZoomed else { return }
    scrollView.frame = bounds
    scrollView.setZoomScale(Self.minZoomScale, animated: false)
    imageView.frame = CGRect(origin: .zero, size: fittedImageSize)
    scrollView.contentSize = imageView.frame.size
    centerImage()
  }

  /// The image's size when aspect-fitted into the view at minimum zoom.
  private var fittedImageSize: CGSize {
    guard let image, image.size.width > 0, image.size.height > 0, bounds.width > 0, bounds.height > 0 else {
      return bounds.size
    }
    let scale = min(bounds.width / image.size.width, bounds.height / image.size.height)
    return CGSize(width: image.size.width * scale, height: image.size.height * scale)
  }

  /// Keeps the image centered while it is smaller than the viewport.
  private func centerImage() {
    let horizontalInset = max(0, (scrollView.bounds.width - scrollView.contentSize.width) / 2)
    let verticalInset = max(0, (scrollView.bounds.height - scrollView.contentSize.height) / 2)
    scrollView.contentInset = UIEdgeInsets(
      top: verticalInset,
      left: horizontalInset,
      bottom: verticalInset,
      right: horizontalInset
    )
  }

  // MARK: - UIScrollViewDelegate

  func viewForZooming(in scrollView: UIScrollView) -> UIView? {
    imageView
  }

  func scrollViewDidZoom(_ scrollView: UIScrollView) {
    centerImage()
  }

  // MARK: - Gestures

  @objc private func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
    if isZoomed {
      scrollView.setZoomScale(Self.minZoomScale, animated: true)
      return
    }
    let point = recognizer.location(in: imageView)
    let zoomSize = CGSize(
      width: scrollView.bounds.width / Self.doubleTapZoomScale,
      height: scrollView.bounds.height / Self.doubleTapZoomScale
    )
    let zoomRect = CGRect(
      x: point.x - zoomSize.width / 2,
      y: point.y - zoomSize.height / 2,
      width: zoomSize.width,
      height: zoomSize.height
    )
    scrollView.zoom(to: zoomRect, animated: true)
  }

  @objc private func handleDismissPan(_ recognizer: UIPanGestureRecognizer) {
    switch recognizer.state {
    case .changed:
      let translation = recognizer.translation(in: self)
      scrollView.transform = CGAffineTransform(translationX: 0, y: translation.y)
    case .ended, .cancelled:
      let velocity = recognizer.velocity(in: self)
      if recognizer.state == .ended, velocity.y > Self.dismissVelocity {
        onSwipeToDismiss?()
      } else {
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0) {
          self.scrollView.transform = .identity
        }
      }
    default:
      break
    }
  }

  // MARK: - UIGestureRecognizerDelegate

  override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
    guard gestureRecognizer === dismissPanRecognizer else {
      return super.gestureRecognizerShouldBegin(gestureRecognizer)
    }
    // Only a mostly-vertical drag of an un-zoomed image can dismiss the viewer.
    let velocity = dismissPanRecognizer.velocity(in: self)
    return !isZoomed && abs(velocity.y) > abs(velocity.x)
  }
}
