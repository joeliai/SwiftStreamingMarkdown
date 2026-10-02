//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import UIKit

/// A source of incremental Markdown text for `StreamedMarkdownView`.
///
/// Each value yielded by `text` is a *complete snapshot* of the Markdown
/// source so far (a growing prefix), not an incremental delta. The view
/// re-parses each snapshot and updates the rendered output.
public protocol StreamedMarkdownSource {
  var text: AsyncStream<String> { get }
}

/// A view that incrementally parses and renders streamed Markdown.
///
/// While the view is in a window it iterates the source's `text` sequence,
/// parsing each snapshot off the main thread and updating only the blocks
/// that changed. Iteration stops when the view leaves its window and restarts,
/// with a fresh `text` sequence, when it returns.
///
/// Like `DocumentView`, this view sizes itself to its rendered content and
/// works inside self-sizing table and collection view cells.
public final class StreamedMarkdownView: UIView {

  /// The streamed Markdown source. Each emission must be the complete Markdown
  /// source so far, not an incremental delta. Setting a new source clears the
  /// rendered content, including any per-block state, and restarts streaming,
  /// so assign the new source when reusing the view in a cell.
  public var source: StreamedMarkdownSource? {
    didSet {
      documentView.renderableDocument = .empty
      restartStreaming()
    }
  }

  /// Render configuration used for both parsing and rendering.
  public var config: MarkdownRenderConfig {
    didSet {
      documentView.config = config
    }
  }

  /// Receives render and interaction events from the rendered content.
  public var listener: MarkdownListener? {
    get { documentView.listener }
    set { documentView.listener = newValue }
  }

  /// Opens links and citations the user taps. Defaults to
  /// `UIApplication.shared.open(_:)`. See `DocumentView.openURL`.
  public var openURL: (URL) -> Void {
    get { documentView.openURL }
    set { documentView.openURL = newValue }
  }

  private let documentView: DocumentView
  private let parser = MarkdownParserImpl()
  private var streamTask: Task<Void, Never>?

  /// Create a `StreamedMarkdownView`.
  /// - Parameters:
  ///   - source: The streamed Markdown source. Each emission must be the
  ///     complete Markdown source so far, not an incremental delta.
  ///   - config: Render configuration. Defaults to `.default`.
  ///   - listener: Optional listener that receives render and interaction events.
  public init(
    source: StreamedMarkdownSource?,
    config: MarkdownRenderConfig = .default,
    listener: MarkdownListener? = nil
  ) {
    self.source = source
    self.config = config
    self.documentView = DocumentView(config: config, listener: listener)
    super.init(frame: .zero)
    embed(documentView)
  }

  public required init?(coder: NSCoder) {
    self.source = nil
    self.config = .default
    self.documentView = DocumentView()
    super.init(coder: coder)
    embed(documentView)
  }

  deinit {
    streamTask?.cancel()
  }

  public override func didMoveToWindow() {
    super.didMoveToWindow()
    restartStreaming()
  }

  public override func sizeThatFits(_ size: CGSize) -> CGSize {
    documentView.sizeThatFits(size)
  }

  public override func systemLayoutSizeFitting(
    _ targetSize: CGSize,
    withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority,
    verticalFittingPriority: UILayoutPriority
  ) -> CGSize {
    documentView.systemLayoutSizeFitting(
      targetSize,
      withHorizontalFittingPriority: horizontalFittingPriority,
      verticalFittingPriority: verticalFittingPriority
    )
  }

  private func restartStreaming() {
    streamTask?.cancel()
    streamTask = nil
    guard window != nil, let source else { return }
    let parser = self.parser
    streamTask = Task { [weak self] in
      for await text in source.text {
        guard !Task.isCancelled, let config = self?.config else { return }
        let renderable = await parser.parse(text: text, config: config)
        guard !Task.isCancelled else { return }
        self?.documentView.renderableDocument = renderable
      }
    }
  }
}
