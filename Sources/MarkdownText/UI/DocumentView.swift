//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import UIKit

/// A UIKit view that renders a pre-parsed `RenderableDocument`. Use this view
/// when you already have a parsed document (e.g. driven by a streaming
/// pipeline); use `MarkdownView` when you want the package to parse for you.
///
/// `DocumentView` sizes itself to its content. It reports the height its
/// content needs for its width through `intrinsicContentSize`,
/// `sizeThatFits(_:)`, and `systemLayoutSizeFitting(_:withHorizontalFittingPriority:verticalFittingPriority:)`,
/// so it can be pinned inside self-sizing table and collection view cells.
/// Whenever that height changes (new content, a loaded image, an expanded
/// table, …) the view invalidates its intrinsic content size and the enclosing
/// `UICollectionViewCell` or `UITableViewCell`, which lets self-sizing cells
/// resize automatically.
///
/// Updating `renderableDocument` keeps the views of blocks whose id and kind
/// are unchanged, so streamed updates only re-render what changed. Block ids
/// are positional, so call `prepareForReuse()` before showing an unrelated
/// document, for example from your cell's `prepareForReuse()`.
public final class DocumentView: UIView, MarkdownLayoutInvalidating {

  /// The rendered document. Setting a new value updates the changed blocks in
  /// place.
  public var renderableDocument: RenderableDocument {
    didSet {
      guard renderableDocument != oldValue else { return }
      reloadBlocks()
      controller.onChange(markdown: renderableDocument)
    }
  }

  /// The render configuration for view-level styling, such as block spacing,
  /// list and table styling, animations, and the text context menu.
  ///
  /// Fonts and colors of the text itself are applied while parsing, so pass the
  /// same config to `MarkdownParser.parse(text:config:)`.
  public var config: MarkdownRenderConfig {
    didSet {
      guard config != oldValue else { return }
      reloadBlocks()
    }
  }

  /// Receives render and interaction events from the rendered content.
  public var listener: MarkdownListener? {
    didSet {
      let isVisible = window != nil
      if isVisible {
        controller.onDisappear()
      }
      controller = makeController()
      reloadBlocks()
      if isVisible {
        controller.onAppear(markdown: renderableDocument)
      }
    }
  }

  /// Opens links and citations the user taps. Defaults to
  /// `UIApplication.shared.open(_:)`; set it to handle URLs yourself, for
  /// example to open them in an in-app browser.
  public var openURL: (URL) -> Void = { UIApplication.shared.open($0) }

  private lazy var controller: MarkdownController = makeController()
  private let blockStack = BlockStackView()
  /// The size most recently reported to Auto Layout or the enclosing cell.
  private var reportedSize: CGSize?

  /// Create a `DocumentView`.
  /// - Parameters:
  ///   - renderableDocument: The parsed Markdown document to render.
  ///   - config: Render configuration. Defaults to `.default`.
  ///   - listener: Optional listener that receives render and interaction events.
  public init(
    renderableDocument: RenderableDocument = .empty,
    config: MarkdownRenderConfig = .default,
    listener: MarkdownListener? = nil
  ) {
    self.renderableDocument = renderableDocument
    self.config = config
    self.listener = listener
    super.init(frame: .zero)
    commonInit()
  }

  public required init?(coder: NSCoder) {
    self.renderableDocument = .empty
    self.config = .default
    self.listener = nil
    super.init(coder: coder)
    commonInit()
  }

  private func commonInit() {
    addSubview(blockStack)
    reloadBlocks()
  }

  private func makeController() -> MarkdownController {
    let controller = MarkdownController(listener: listener)
    controller.onTextSelectionRequested = { [weak self] in
      self?.presentTextSelection()
    }
    controller.openURL = { [weak self] url in
      self?.openURL(url)
    }
    return controller
  }

  /// Prepares the view to display an unrelated document: removes the rendered
  /// blocks so per-block state, such as an expanded table's actions, doesn't
  /// carry over to blocks at the same position in the next document. Call it
  /// from the `prepareForReuse()` of the cell that hosts the view.
  public func prepareForReuse() {
    renderableDocument = .empty
  }

  private func reloadBlocks() {
    blockStack.spacing = config.blockSpacing
    blockStack.update(
      renderables: renderableDocument.renderables,
      context: BlockContext(config: config, controller: controller)
    )
    invalidateMarkdownLayout()
  }

  // MARK: - Lifecycle

  public override func didMoveToWindow() {
    super.didMoveToWindow()
    if window != nil {
      controller.onAppear(markdown: renderableDocument)
    } else {
      controller.onDisappear()
    }
  }

  // MARK: - Sizing

  public override func sizeThatFits(_ size: CGSize) -> CGSize {
    let width = size.width.isFinite && size.width > 0 ? size.width : layoutWidth
    return CGSize(width: width, height: contentHeight(forWidth: width))
  }

  public override var intrinsicContentSize: CGSize {
    let width = layoutWidth
    guard width > 0 else {
      return CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
    }
    let height = contentHeight(forWidth: width)
    reportedSize = CGSize(width: width, height: height)
    return CGSize(width: UIView.noIntrinsicMetric, height: height)
  }

  public override func systemLayoutSizeFitting(
    _ targetSize: CGSize,
    withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority,
    verticalFittingPriority: UILayoutPriority
  ) -> CGSize {
    guard horizontalFittingPriority >= .required, targetSize.width.isFinite, targetSize.width > 0 else {
      return super.systemLayoutSizeFitting(
        targetSize,
        withHorizontalFittingPriority: horizontalFittingPriority,
        verticalFittingPriority: verticalFittingPriority
      )
    }
    return CGSize(width: targetSize.width, height: contentHeight(forWidth: targetSize.width))
  }

  /// The content height for `width`, rounded up to whole points so Auto
  /// Layout's pixel rounding never clips the last line.
  private func contentHeight(forWidth width: CGFloat) -> CGFloat {
    blockStack.height(forWidth: width).rounded(.up)
  }

  /// The width to size the content for: the view's own width once laid out,
  /// otherwise an estimate from the closest laid-out ancestor that is refined
  /// on the first layout pass.
  private var layoutWidth: CGFloat {
    if bounds.width > 0 {
      return bounds.width
    }
    var ancestor = superview
    while let view = ancestor {
      if view.bounds.width > 0 {
        return view.bounds.width
      }
      ancestor = view.superview
    }
    return 0
  }

  public override func layoutSubviews() {
    super.layoutSubviews()
    let width = bounds.width
    let height = contentHeight(forWidth: width)
    blockStack.frame = CGRect(x: 0, y: 0, width: width, height: height)
    if width > 0, reportedSize?.height != height {
      contentSizeDidChange()
    }
  }

  func invalidateMarkdownLayout() {
    setNeedsLayout()
    contentSizeDidChange()
  }

  /// Tells Auto Layout and any enclosing self-sizing collection or table view
  /// cell that the content height may have changed.
  private func contentSizeDidChange() {
    invalidateIntrinsicContentSize()
    let width = layoutWidth
    guard width > 0 else { return }
    let height = contentHeight(forWidth: width)
    guard reportedSize?.height != height else { return }
    reportedSize = CGSize(width: width, height: height)
    // Self-sizing cells only re-measure when the cell itself is invalidated.
    var ancestor = superview
    while let view = ancestor {
      if view is UICollectionViewCell || view is UITableViewCell {
        view.invalidateIntrinsicContentSize()
        return
      }
      ancestor = view.superview
    }
  }

  // MARK: - Text selection

  private func presentTextSelection() {
    guard let presenter = nearestViewController, presenter.presentedViewController == nil else { return }
    let textSelection = TextSelectionViewController(text: renderableDocument.plainText, config: config)
    presenter.present(textSelection, animated: true)
  }
}
