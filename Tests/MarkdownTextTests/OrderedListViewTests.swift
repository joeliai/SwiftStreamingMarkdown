//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import Markdown
@testable import SwiftStreamingMarkdown
import XCTest

@MainActor
final class OrderedListViewTests: SnapshotTestCase {

  func testOrderedListView() async throws {
    let text: [String] = (0..<40).map { i in
      "item \(i+1)"
    }
    let items = await listItems(parsing: text)

    assertBlock(.orderedList(id: "list", items: items))
  }

  func testOrderedListViewWithCitations() async throws {
    let citationMarker = CitationCoder.default.citationMarker
    let textWithCitations: [String] = [
      "First item with citation [\(citationMarker)](http://example.com?citationMarker=\(citationMarker)&citationTitle=ESPN&citationA11yValue=ESPN%20Sports)",
      "Second item [\(citationMarker)](http://example.com?citationMarker=\(citationMarker)&citationTitle=Google&citationA11yValue=Google%20Search) with citation",
      "Plain text item without citations",
      "Mixed content [\(citationMarker)](http://example.com?citationMarker=\(citationMarker)&citationTitle=Microsoft&citationA11yValue=Microsoft%20Corporation) and more text"
    ]
    let items = await listItems(parsing: textWithCitations)

    // Validates that the first-line alignment handles leading citations.
    assertBlock(.orderedList(id: "list", items: items))
  }

  private func listItems(parsing paragraphs: [String]) async -> [MarkdownListItem] {
    let parser = MarkdownParserImpl()
    var items: [MarkdownListItem] = []
    for paragraph in paragraphs {
      let document = await parser.parse(text: paragraph)
      items.append(MarkdownListItem(children: document.convert(with: .default), startsWithBold: false))
    }
    return items
  }
}
