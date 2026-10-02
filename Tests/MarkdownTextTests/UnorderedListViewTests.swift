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
}
