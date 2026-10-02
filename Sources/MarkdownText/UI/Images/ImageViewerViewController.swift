//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import UIKit

/// The built-in fullscreen image viewer presented when a user taps a rendered
/// block-level image and `ImageConfig.fullscreenViewerEnabled` is `true`.
///
/// Displays the image on a black background inside a zoomable, pannable
/// `ZoomableImageView`, with a close control and swipe-to-dismiss.
///
/// - Important: Image support is **experimental**. See
///   `MarkdownRenderConfig.imageConfig`.
final class ImageViewerViewController: UIViewController {

  private let source: ImageData.Source
  private let alt: String
  private weak var controller: MarkdownController?

  private let zoomableImageView = ZoomableImageView()
  private let activityIndicator = UIActivityIndicatorView(style: .medium)
  private let failureView = BlockImageFailureView()
  private let closeButton = UIButton(type: .system)
  private var loadTask: Task<Void, Never>?

  init(source: ImageData.Source, alt: String, controller: MarkdownController?) {
    self.source = source
    self.alt = alt
    self.controller = controller
    super.init(nibName: nil, bundle: nil)
    modalPresentationStyle = .fullScreen
  }

  required init?(coder: NSCoder) {
    nil
  }

  deinit {
    loadTask?.cancel()
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .black

    zoomableImageView.isAccessibilityElement = true
    zoomableImageView.accessibilityTraits = .image
    zoomableImageView.accessibilityLabel = alt.isEmpty ? String.imageLabel : alt
    zoomableImageView.onSwipeToDismiss = { [weak self] in
      self?.dismiss(animated: true)
    }
    activityIndicator.color = .white
    activityIndicator.hidesWhenStopped = true
    failureView.isHidden = true

    let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
    blurView.isUserInteractionEnabled = false
    blurView.layer.cornerRadius = 20
    blurView.clipsToBounds = true
    closeButton.insertSubview(blurView, at: 0)
    blurView.translatesAutoresizingMaskIntoConstraints = false
    let symbolConfiguration = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
    closeButton.setImage(UIImage(systemName: "xmark", withConfiguration: symbolConfiguration), for: .normal)
    closeButton.tintColor = .white
    closeButton.accessibilityLabel = String.imageViewerCloseLabel
    closeButton.addTarget(self, action: #selector(close), for: .touchUpInside)

    for subview in [zoomableImageView, activityIndicator, failureView, closeButton] {
      subview.translatesAutoresizingMaskIntoConstraints = false
      view.addSubview(subview)
    }
    NSLayoutConstraint.activate([
      zoomableImageView.topAnchor.constraint(equalTo: view.topAnchor),
      zoomableImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      zoomableImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      zoomableImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
      failureView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      failureView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      failureView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
      failureView.heightAnchor.constraint(equalToConstant: BlockImageFailureView.minimumHeight),
      closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
      closeButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
      closeButton.widthAnchor.constraint(equalToConstant: 40),
      closeButton.heightAnchor.constraint(equalToConstant: 40),
      blurView.topAnchor.constraint(equalTo: closeButton.topAnchor),
      blurView.bottomAnchor.constraint(equalTo: closeButton.bottomAnchor),
      blurView.leadingAnchor.constraint(equalTo: closeButton.leadingAnchor),
      blurView.trailingAnchor.constraint(equalTo: closeButton.trailingAnchor)
    ])

    loadImage()
  }

  private func loadImage() {
    if case .assetCatalog(let name) = source {
      show(UIImage(named: name))
      return
    }
    activityIndicator.startAnimating()
    let source = self.source
    loadTask = Task { [weak self, weak controller = self.controller] in
      let image = await ImageLoader.image(for: source, controller: controller)
      guard !Task.isCancelled else { return }
      self?.show(image)
    }
  }

  private func show(_ image: UIImage?) {
    activityIndicator.stopAnimating()
    zoomableImageView.image = image
    failureView.isHidden = image != nil
  }

  @objc private func close() {
    dismiss(animated: true)
  }
}
