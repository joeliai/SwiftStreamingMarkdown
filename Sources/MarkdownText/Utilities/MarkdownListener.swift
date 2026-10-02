//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import Foundation

public protocol MarkdownListener {
  func onRender(markdown: RenderableDocument) async
  func onTableCopyTap(content: String) async
  func onTableDownloadTap(content: String) async
  func onContextMenuAppear(id: String, selectedContent: String) async
  func onContextMenuTap(id: String, selectedContent: String) async
  func onImageTap(image: MarkdownImage) async

  /// Resolves a bundled-resource image that the app's main bundle does not
  /// contain — for example one shipped inside a dependency package or a
  /// framework rather than the app target.
  ///
  /// The renderer calls this only after failing to find `fileName`(`.ext`) in
  /// `Bundle.main`. Return a readable file URL for the resource, or `nil` when
  /// it cannot be provided. Defaults to `nil`.
  ///
  /// - Important: Image support is **experimental**.
  func resolveBundledResource(fileName: String, ext: String?) -> URL?
}

public extension MarkdownListener {
  func resolveBundledResource(fileName: String, ext: String?) -> URL? { nil }
}

/// Routes render and interaction events from the rendered views to the
/// configured `MarkdownListener`. Owned by `DocumentView`; all methods are
/// expected to be called on the main thread.
public final class MarkdownController {

  private let listener: MarkdownListener?
  private var continuation: AsyncStream<RenderableDocument>.Continuation?
  private var listenerTask: Task<Void, Never>?

  /// Invoked when the built-in "Select more text" edit-menu action is tapped.
  /// `DocumentView` sets this to present the text selection modal.
  var onTextSelectionRequested: (() -> Void)?

  /// Opens links and citations the user taps. `DocumentView` routes this to
  /// its `openURL` property.
  var openURL: ((URL) -> Void)?

  init(listener: MarkdownListener?) {
    self.listener = listener
  }

  /// Request presentation of the full-document text selection modal.
  func requestTextSelection() {
    onTextSelectionRequested?()
  }

  func onAppear(markdown: RenderableDocument) {
    cleanup()

    guard let listener else {
      return
    }

    let stream = AsyncStream<RenderableDocument>(bufferingPolicy: .bufferingNewest(1)) { continuation in
      self.continuation = continuation
    }

    listenerTask = Task {
      // Deliver the initial markdown directly so it can't be overwritten
      // in the 1-slot buffer by an `onChange` arriving before this task
      // starts iterating the stream.
      await listener.onRender(markdown: markdown)
      for await md in stream {
        await listener.onRender(markdown: md)
      }
    }
  }

  func onChange(markdown: RenderableDocument) {
    continuation?.yield(markdown)
  }

  func onDisappear() {
    cleanup()
  }

  func onTableCopyTap(content: String) {
    Task {
      await listener?.onTableCopyTap(content: content)
    }
  }

  func onTableDownloadTap(content: String) {
    Task {
      await listener?.onTableDownloadTap(content: content)
    }
  }

  func onContextMenuAppear(id: String, selectedContent: String) {
    Task {
      await listener?.onContextMenuAppear(id: id, selectedContent: selectedContent)
    }
  }

  func onContextMenuTap(id: String, selectedContent: String) {
    Task {
      await listener?.onContextMenuTap(id: id, selectedContent: selectedContent)
    }
  }

  func onImageTap(image: MarkdownImage) {
    Task {
      await listener?.onImageTap(image: image)
    }
  }

  /// Asks the listener to resolve a bundled-resource image not present in the
  /// app's main bundle. Returns `nil` when there is no listener or it cannot
  /// provide the resource.
  func resolveBundledResource(fileName: String, ext: String?) -> URL? {
    listener?.resolveBundledResource(fileName: fileName, ext: ext)
  }

  private func cleanup() {
    continuation?.finish()
    continuation = nil
    listenerTask?.cancel()
    listenerTask = nil
  }
}
