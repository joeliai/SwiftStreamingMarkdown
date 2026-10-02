//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

@testable import SwiftStreamingMarkdown
import UIKit
import XCTest

@MainActor
final class DocumentViewTests: XCTestCase {

  private let parser = MarkdownParserImpl()

  override func setUp() {
    super.setUp()
    ParagraphViewCache.shared.clearCache()
  }

  // MARK: - Updates

  func testUnchangedBlocksKeepTheirViewsAcrossUpdates() async {
    let first = await parser.parse(text: "First paragraph.\n\nSecond", config: .default)
    let second = await parser.parse(text: "First paragraph.\n\nSecond paragraph grows\n\n- a new list", config: .default)
    let view = DocumentView(renderableDocument: first)
    view.frame = CGRect(x: 0, y: 0, width: 320, height: 400)
    view.layoutIfNeeded()
    let before = view.descendants(of: ParagraphUIView.self)
    XCTAssertEqual(before.count, 2)

    view.renderableDocument = second
    view.layoutIfNeeded()

    let after = view.descendants(of: ParagraphUIView.self)
    XCTAssertEqual(after.count, 3, "The new list item should add a paragraph")
    XCTAssertTrue(after[0] === before[0], "An unchanged paragraph keeps its view")
    XCTAssertTrue(after[1] === before[1], "A growing paragraph is updated in place")
    XCTAssertEqual(after[1].paragraphContents.string, "Second paragraph grows")
  }

  func testPrepareForReuseRendersTheNextDocumentWithFreshBlockViews() async throws {
    let tableMarkdown = "| A | B |\n| --- | --- |\n| 1 | 2 |"
    let first = await parser.parse(text: tableMarkdown, config: .default)
    let second = await parser.parse(text: "| C | D |\n| --- | --- |\n| 3 | 4 |", config: .default)
    let view = DocumentView(renderableDocument: first)
    let firstTable = try XCTUnwrap(view.descendants(of: TableView.self).first)

    // Without a reset, the table at the same position keeps its view (and any
    // state such as expanded actions).
    view.renderableDocument = second
    XCTAssertTrue(view.descendants(of: TableView.self).first === firstTable)

    view.prepareForReuse()
    XCTAssertTrue(view.renderableDocument.isEmpty)
    XCTAssertTrue(view.descendants(of: TableView.self).isEmpty)

    view.renderableDocument = await parser.parse(text: tableMarkdown, config: .default)
    let freshTable = try XCTUnwrap(view.descendants(of: TableView.self).first)
    XCTAssertFalse(freshTable === firstTable, "The next document must get fresh block views")
  }

  func testMarkdownViewPrepareForReuseRendersTheSameTextAgain() async {
    let view = MarkdownView(text: "Reused text.")
    let documentView = view.descendants(of: DocumentView.self).first
    await waitUntil { documentView?.renderableDocument.isEmpty == false }

    view.prepareForReuse()
    XCTAssertEqual(view.text, "")
    XCTAssertEqual(documentView?.renderableDocument.isEmpty, true)

    view.text = "Reused text."
    await waitUntil { documentView?.renderableDocument.plainText == "Reused text." }
  }

  // MARK: - Links

  func testCitationActivationOpensThroughOpenURL() async throws {
    let markdown = "See [9F742443](https://example.com/report?citationMarker=9F742443&citationTitle=Report&citationA11yValue=Report)."
    let document = await parser.parse(text: markdown, config: .default)
    let view = DocumentView(renderableDocument: document)
    var openedURLs: [URL] = []
    view.openURL = { openedURLs.append($0) }

    // VoiceOver activates citations through a custom action that takes the
    // same path as a tap.
    let paragraph = try XCTUnwrap(view.descendants(of: ParagraphUIView.self).first)
    let action = try XCTUnwrap(paragraph.accessibilityCustomActions?.first)
    XCTAssertEqual(action.actionHandler?(action), true)

    XCTAssertEqual(openedURLs.count, 1)
    XCTAssertEqual(openedURLs.first?.host, "example.com")
  }

  // MARK: - Sizing

  func testSizingAPIsAgree() async {
    let document = await parser.parse(text: richMarkdownSample, config: .default)
    let view = DocumentView(renderableDocument: document)
    let width: CGFloat = 320

    let fitted = view.sizeThatFits(CGSize(width: width, height: CGFloat.greatestFiniteMagnitude))
    let systemFitted = view.systemLayoutSizeFitting(
      CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
      withHorizontalFittingPriority: .required,
      verticalFittingPriority: .fittingSizeLevel
    )
    view.frame = CGRect(x: 0, y: 0, width: width, height: fitted.height)
    view.layoutIfNeeded()

    XCTAssertGreaterThan(fitted.height, 0)
    XCTAssertEqual(systemFitted.height, fitted.height)
    XCTAssertEqual(view.intrinsicContentSize.height, fitted.height)
  }

  func testAutoLayoutCorrectsTheEstimatedWidthOnLayout() async {
    let document = await parser.parse(text: richMarkdownSample, config: .default)
    let container = UIView(frame: CGRect(x: 0, y: 0, width: 360, height: 3000))
    let view = DocumentView(renderableDocument: document)
    view.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(view)
    // Insets make the first-pass estimate (the container's width) too wide.
    NSLayoutConstraint.activate([
      view.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),
      view.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 40),
      view.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -40)
    ])

    await settleLayout(of: container)

    let expected = view.sizeThatFits(CGSize(width: 280, height: CGFloat.greatestFiniteMagnitude)).height
    XCTAssertEqual(view.frame.width, 280)
    XCTAssertEqual(view.frame.height, expected)
  }

  // MARK: - MarkdownView

  func testMarkdownViewParsesAndRendersText() async {
    let view = MarkdownView(text: "# Title\n\nSome **bold** text.")
    let documentView = view.descendants(of: DocumentView.self).first

    await waitUntil { documentView?.renderableDocument.isEmpty == false }

    XCTAssertEqual(documentView?.renderableDocument.plainText, "Title\n\nSome bold text.")
    XCTAssertGreaterThan(view.sizeThatFits(CGSize(width: 320, height: CGFloat.greatestFiniteMagnitude)).height, 0)
  }

  // MARK: - StreamedMarkdownView

  func testStreamedMarkdownViewStreamsOnlyWhileInAWindow() async throws {
    let view = StreamedMarkdownView(source: SnapshotSource(snapshots: ["Hel", "Hello **wor", "Hello **world**"]))
    let documentView = try XCTUnwrap(view.descendants(of: DocumentView.self).first)

    try? await Task.sleep(nanoseconds: 100_000_000)
    XCTAssertTrue(documentView.renderableDocument.isEmpty, "Streaming must not start before the view is in a window")

    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 600))
    view.frame = window.bounds
    window.addSubview(view)
    window.isHidden = false
    defer { window.isHidden = true }

    await waitUntil { documentView.renderableDocument.plainText == "Hello world" }
  }
}

/// Emits each snapshot once, then finishes.
private struct SnapshotSource: StreamedMarkdownSource {
  let snapshots: [String]

  var text: AsyncStream<String> {
    AsyncStream { continuation in
      for snapshot in snapshots {
        continuation.yield(snapshot)
      }
      continuation.finish()
    }
  }
}
