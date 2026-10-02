//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import Markdown
@testable import SwiftStreamingMarkdown
import UIKit
import XCTest

@MainActor
final class UnorderedListViewTests: SnapshotTestCase {

  private let padding = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)

  func testUnorderedListView() async throws {
    let paragraphs = ["item 1", "item 2", "item 3, this is a very long item with a lot of texts. it may create a multi-line paragraph."]
    let items = await listItems(parsing: paragraphs)

    assertBlock(.unorderedList(id: "list", items: items, nestedLevel: 0), insets: padding)
  }

  func testUnorderedListViewWithCitations() async throws {
    let citationMarker = "9F742443"
    let paragraphs = [
      "item 1",
      "Item with citation [\(citationMarker)](http://example.com?citationMarker=\(citationMarker)&citationTitle=ESPN&citationA11yValue=ESPN%20Sports)",
      "item 3"
    ]
    let items = await listItems(parsing: paragraphs)

    assertBlock(.unorderedList(id: "list", items: items, nestedLevel: 0), insets: padding)
  }

  func testTaskListView() async throws {
    let text = """
    - [x] completed task
    - [ ] open task with a longer trailing description to exercise wrapping behavior
    - regular item mixed into the same list
    """
    let renderable = try await firstRenderable(parsing: text)

    assertBlock(renderable, insets: padding)
  }

  /// Like SwiftUI's resizable symbol images, each marker's glyph fills its
  /// 12-point (checkbox) or 4-point (bullet) box, centered in the 22-point
  /// marker column, rather than shrinking by the symbol image's padding.
  func testMarkerGlyphsFillTheirBoxes() async throws {
    let cases: [(markdown: String, side: CGFloat)] = [
      ("- [x] completed task", 12),
      ("- [ ] open task", 12),
      ("- regular item", 4)
    ]
    for (markdown, side) in cases {
      let renderable = try await firstRenderable(parsing: markdown)
      let glyph = try XCTUnwrap(markerGlyphFrame(of: renderable), markdown)
      XCTAssertEqual(glyph.width, side, accuracy: 0.5, markdown)
      XCTAssertEqual(glyph.height, side, accuracy: 0.5, markdown)
      XCTAssertEqual(glyph.midX, 11, accuracy: 0.5, markdown)
    }
  }

  func testNestedUnorderedListView() async throws {
    let text = """
    - Top level item 1
      - Nested item A
        - Deeply nested item X
        - Deeply nested item Y with a longer trailing description to exercise wrapping
      - Nested item B
    - Top level item 2
      - Nested item C
    """
    let renderable = try await firstRenderable(parsing: text)

    assertBlock(renderable, insets: padding)
  }

  private func listItems(parsing paragraphs: [String]) async -> [MarkdownListItem] {
    let parser = MarkdownParserImpl()
    var items: [MarkdownListItem] = []
    for paragraph in paragraphs {
      let document = await parser.parse(text: paragraph)
      items.append(MarkdownListItem(children: [document.convert(with: .default)[0]], startsWithBold: false))
    }
    return items
  }

  private func firstRenderable(parsing text: String) async throws -> MarkdownRenderable {
    let document = await MarkdownParserImpl().parse(text: text)
    let renderable = try XCTUnwrap(document.convert(with: .default).first)
    guard case .unorderedList = renderable else {
      XCTFail("Expected the parsed document to start with an unordered list")
      throw CancellationError()
    }
    return renderable
  }

  /// Renders a top-level list at 3x and returns, in points, the bounds of the
  /// opaque pixels in its 22-point marker column, which holds only the markers.
  private func markerGlyphFrame(of renderable: MarkdownRenderable) -> CGRect? {
    let listView = makeBlockView(for: renderable, context: BlockContext(config: .default, controller: nil))
    listView.frame = CGRect(x: 0, y: 0, width: 320, height: listView.height(forWidth: 320))
    listView.layoutIfNeeded()

    let scale: CGFloat = 3
    let width = 22 * Int(scale)
    let height = Int((listView.bounds.height * scale).rounded(.up))
    guard height > 0,
          let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
          ),
          let data = context.data
    else {
      return nil
    }
    // Flip to UIKit's top-left origin so that memory rows run top to bottom.
    context.translateBy(x: 0, y: CGFloat(height))
    context.scaleBy(x: scale, y: -scale)
    listView.layer.render(in: context)

    let pixels = data.assumingMemoryBound(to: UInt8.self)
    var minX = width, minY = height, maxX = -1, maxY = -1
    for y in 0..<height {
      for x in 0..<width where pixels[y * context.bytesPerRow + x * 4 + 3] > 127 {
        minX = min(minX, x)
        maxX = max(maxX, x)
        minY = min(minY, y)
        maxY = max(maxY, y)
      }
    }
    guard minX <= maxX, minY <= maxY else {
      return nil
    }
    return CGRect(
      x: CGFloat(minX) / scale,
      y: CGFloat(minY) / scale,
      width: CGFloat(maxX - minX + 1) / scale,
      height: CGFloat(maxY - minY + 1) / scale
    )
  }
}
