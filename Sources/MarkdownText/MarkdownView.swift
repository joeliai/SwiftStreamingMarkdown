//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import UIKit

/// A view that parses and renders Markdown text. Parsing happens off the main
/// thread whenever `text` or `config` changes. Use `DocumentView` instead if
/// you want to perform the parsing yourself.
///
/// Like `DocumentView`, this view sizes itself to its rendered content and
/// works inside self-sizing table and collection view cells.
public final class MarkdownView: UIView {

  /// The Markdown source to parse and render.
  public var text: String {
    didSet {
      guard text != oldValue else { return }
      parse()
    }
  }

  /// Render configuration used for both parsing and rendering.
  public var config: MarkdownRenderConfig {
    didSet {
      guard config != oldValue else { return }
      documentView.config = config
      parse()
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
  private var parseTask: Task<Void, Never>?

  /// Create a `MarkdownView`.
  /// - Parameters:
  ///   - text: The raw Markdown source to parse and render.
  ///   - config: Render configuration. Defaults to `.default`.
  ///   - listener: Optional listener that receives render and interaction events.
  public init(
    text: String = "",
    config: MarkdownRenderConfig = .default,
    listener: MarkdownListener? = nil
  ) {
    self.text = text
    self.config = config
    self.documentView = DocumentView(config: config, listener: listener)
    super.init(frame: .zero)
    embed(documentView)
    parse()
  }

  public required init?(coder: NSCoder) {
    self.text = ""
    self.config = .default
    self.documentView = DocumentView()
    super.init(coder: coder)
    embed(documentView)
  }

  deinit {
    parseTask?.cancel()
  }

  /// Prepares the view to display unrelated Markdown, for example when its cell
  /// is reused: clears `text` and the rendered blocks. See
  /// `DocumentView.prepareForReuse()`.
  public func prepareForReuse() {
    text = ""
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

  private func parse() {
    parseTask?.cancel()
    guard !text.isEmpty else {
      documentView.renderableDocument = .empty
      return
    }
    let text = self.text
    let config = self.config
    let parser = self.parser
    parseTask = Task { [weak self] in
      let renderable = await parser.parse(text: text, config: config)
      guard !Task.isCancelled else { return }
      self?.documentView.renderableDocument = renderable
    }
  }
}
