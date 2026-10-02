//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import UIKit

/// Renders a block-level Markdown image, loaded asynchronously from a remote
/// URL, resolved from the app's asset catalog, or loaded from a bundled
/// resource file. Tapping the image notifies the `MarkdownListener` and, when
/// enabled, opens the fullscreen image viewer.
///
/// - Important: Image support is **experimental**. See
///   `MarkdownRenderConfig.imageConfig`.
final class BlockImageView: UIView, MarkdownBlockView {

  private enum State: Equatable {
    case loading
    case loaded(UIImage)
    case failed
  }

  private let imageView = UIImageView()
  private let loadingView = BlockImageLoadingView()
  private let failureView = BlockImageFailureView()

  private var data: ImageData?
  private var config: MarkdownRenderConfig = .default
  private weak var controller: MarkdownController?
  private var state: State = .loading
  private var loadTask: Task<Void, Never>?

  init() {
    super.init(frame: .zero)
    imageView.contentMode = .scaleAspectFit
    addSubview(imageView)
    addSubview(loadingView)
    addSubview(failureView)

    isAccessibilityElement = true
    accessibilityTraits = .image
    addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap)))
  }

  required init?(coder: NSCoder) {
    nil
  }

  deinit {
    loadTask?.cancel()
  }

  // MARK: - MarkdownBlockView

  func update(with renderable: MarkdownRenderable, context: BlockContext) {
    guard case .image(_, let data) = renderable else { return }
    config = context.config
    controller = context.controller
    accessibilityLabel = data.alt.isEmpty ? String.imageLabel : data.alt
    guard data != self.data else { return }
    self.data = data
    load(data.source)
  }

  func height(forWidth width: CGFloat) -> CGFloat {
    switch state {
    case .loading:
      return BlockImageLoadingView.height
    case .failed:
      return failureView.preferredHeight
    case .loaded(let image):
      guard image.size.width > 0 else { return 0 }
      return (width * image.size.height / image.size.width).rounded(.up)
    }
  }

  override func sizeThatFits(_ size: CGSize) -> CGSize {
    CGSize(width: size.width, height: height(forWidth: size.width))
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    imageView.frame = bounds
    loadingView.frame = bounds
    failureView.frame = bounds
  }

  // MARK: - Loading

  private func load(_ source: ImageData.Source?) {
    loadTask?.cancel()
    guard let source else {
      setState(.failed)
      return
    }
    if case .assetCatalog(let name) = source {
      setState(UIImage(named: name).map(State.loaded) ?? .failed)
      return
    }
    setState(.loading)
    loadTask = Task { [weak self, weak controller = self.controller] in
      let image = await ImageLoader.image(for: source, controller: controller)
      guard !Task.isCancelled, let self else { return }
      self.setState(image.map(State.loaded) ?? .failed)
    }
  }

  private func setState(_ newState: State) {
    let previousState = state
    state = newState
    if case .loaded(let image) = newState {
      imageView.image = image
    } else {
      imageView.image = nil
    }
    imageView.isHidden = imageView.image == nil
    loadingView.isHidden = newState != .loading
    failureView.isHidden = newState != .failed
    if newState != previousState {
      setNeedsMarkdownLayout()
    }
    setNeedsLayout()
  }

  // MARK: - Tap

  @objc private func handleTap() {
    guard let data, let source = data.source else { return }
    if config.imageConfig.fullscreenViewerEnabled, let presenter = nearestViewController {
      let viewer = ImageViewerViewController(source: source, alt: data.alt, controller: controller)
      presenter.present(viewer, animated: true)
    }
    Task { [weak controller = self.controller] in
      guard let image = await data.makeMarkdownImage(controller: controller) else { return }
      controller?.onImageTap(image: image)
    }
  }
}
