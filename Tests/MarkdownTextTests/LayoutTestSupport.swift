//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import UIKit
import XCTest
@testable import SwiftStreamingMarkdown

/// Markdown that exercises every frame-based block type that renders
/// synchronously: headings, paragraphs, lists, a table, a quote, and code.
let richMarkdownSample = """
# Release notes

SwiftStreamingMarkdown renders **streamed** Markdown with *UIKit* views, so it can be hosted directly in collection view cells.

1. Parse the snapshot off the main thread.
2. Diff the blocks by id.
   - Unchanged blocks keep their views.
   - Changed blocks update in place.

| Block | View |
| --- | --- |
| Paragraph | `ParagraphUIView` |
| Table | `TableView` |

> Self-sizing cells resize when content grows.

```swift
let view = DocumentView(renderableDocument: document)
```
"""

extension XCTestCase {
  /// Polls `condition` on the main actor until it holds or `timeout` elapses.
  @MainActor
  func waitUntil(
    timeout: TimeInterval = 5,
    file: StaticString = #filePath,
    line: UInt = #line,
    _ condition: () -> Bool
  ) async {
    let deadline = Date().addingTimeInterval(timeout)
    while !condition() {
      guard Date() < deadline else {
        XCTFail("Timed out waiting for condition", file: file, line: line)
        return
      }
      try? await Task.sleep(nanoseconds: 10_000_000)
    }
  }

  /// Lets UIKit run a few layout passes and run-loop turns, which is when
  /// self-sizing invalidations are processed.
  @MainActor
  func settleLayout(of view: UIView) async {
    for _ in 0..<5 {
      view.layoutIfNeeded()
      try? await Task.sleep(nanoseconds: 20_000_000)
    }
  }
}

extension UIView {
  /// All descendants of type `T`, in depth-first subview order.
  func descendants<T: UIView>(of type: T.Type) -> [T] {
    subviews.flatMap { subview -> [T] in
      let match = (subview as? T).map { [$0] } ?? []
      return match + subview.descendants(of: type)
    }
  }
}
