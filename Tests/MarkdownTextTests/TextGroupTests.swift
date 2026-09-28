//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import Markdown
@testable import SwiftStreamingMarkdown
import SwiftUI
import XCTest

@MainActor
final class TextGroupTests: XCTestCase {

  private let parser = MarkdownParserImpl()

  private func renderableDocument(for text: String, config: MarkdownRenderConfig = .default) async -> RenderableDocument {
    let document = await parser.parse(text: text)
    return await RenderableDocument(document: document, config: config)
  }

  private func textGroup(_ text: String, config: MarkdownRenderConfig = .default) async -> (blocks: [MarkdownRenderable], content: NSMutableAttributedString)? {
    guard case .textGroup(_, let blocks, let content) = await renderableDocument(for: text, config: config).renderables.first else {
      XCTFail("Expected a text group")
      return nil
    }
    return (blocks, content)
  }

  // MARK: - Grouping

  func test_adjacentHeadingsAndParagraphs_areGroupedIntoOneRenderable() async {
    let renderables = await renderableDocument(for: "# Title\n\nFirst paragraph.\n\nSecond paragraph.\n\n## Section").renderables

    XCTAssertEqual(renderables.count, 1)
    guard case .textGroup(_, let blocks, let content) = renderables.first else {
      return XCTFail("Expected adjacent text blocks to be grouped")
    }
    XCTAssertEqual(blocks.compactMap { $0.plainText }, ["Title", "First paragraph.", "Second paragraph.", "Section"])
    XCTAssertEqual(content.string, "Title\nFirst paragraph.\nSecond paragraph.\nSection")
  }

  func test_textBlocksSeparatedByOtherBlocks_areNotGrouped() async {
    let renderables = await renderableDocument(for: "# Intro\n\n- item\n\nOutro.").renderables

    XCTAssertEqual(renderables.count, 3)
    guard case .heading = renderables[0], case .unorderedList = renderables[1], case .paragraph = renderables[2] else {
      return XCTFail("Expected heading, list, paragraph")
    }
  }

  func test_blockSpacingBelowLineSpacing_keepsBlocksSeparate() async {
    let config = MarkdownRenderConfig.default.withBlockSpacing(value: 2)
    let renderables = await renderableDocument(for: "# Title\n\nBody.", config: config).renderables

    XCTAssertEqual(renderables.count, 2, "A paragraph break can't be spaced tighter than the line spacing")
  }

  func test_group_keepsFirstBlockID_asBlocksStreamIn() async {
    let before = await renderableDocument(for: "# Title").renderables
    let after = await renderableDocument(for: "# Title\n\nBody").renderables

    XCTAssertEqual(before.map(\.id), after.map(\.id), "A stable ID keeps SwiftUI updating the same text view")
  }

  func test_blockSpacing_appliesOnlyToEachBlocksFirstLine() async {
    let config = MarkdownRenderConfig.default
    guard let group = await textGroup("First.\n\nSecond, line one\nSecond, line two", config: config) else { return }
    func spacingBefore(_ text: String) -> CGFloat {
      let location = (group.content.string as NSString).range(of: text).location
      let style = group.content.attribute(.paragraphStyle, at: location, effectiveRange: nil) as? NSParagraphStyle
      return style?.paragraphSpacingBefore ?? 0
    }

    XCTAssertEqual(spacingBefore("First."), 0)
    XCTAssertEqual(spacingBefore("Second, line one"), config.blockSpacing - MarkdownRenderable.paragraphLineSpacing)
    XCTAssertEqual(spacingBefore("Second, line two"), 0, "Soft-break lines belong to the same block")
  }

  func test_plainText_keepsBlankLineBetweenGroupedBlocks() async {
    let document = await renderableDocument(for: "# Title\n\nFirst.\n\nSecond.")

    XCTAssertEqual(document.plainText, "Title\n\nFirst.\n\nSecond.")
  }

  // MARK: - Rendering

  /// A group must lay out exactly like its blocks stacked `blockSpacing` apart,
  /// so grouping is visually a no-op. Pairs keep one break's error from
  /// cancelling out another's.
  func test_groupHeight_matchesStackedBlocks_forEveryKindOfBreak() async {
    let heading = "# A heading long enough to wrap onto a second line"
    let paragraph = "A paragraph that is long enough to wrap across several lines at this width."
    let pairs = [(heading, paragraph), (paragraph, heading), (paragraph, paragraph), (heading, heading)]
    for blockSpacing: CGFloat in [MarkdownRenderConfig.defaultBlockSpacing, 10] {
      let config = MarkdownRenderConfig.default.withBlockSpacing(value: blockSpacing)
      for (first, second) in pairs {
        guard let group = await textGroup("\(first)\n\n\(second)", config: config) else { return }

        let stacked = group.blocks.map(measuredHeight(ofBlock:)).reduce(blockSpacing, +)

        XCTAssertEqual(measuredHeight(of: group.content), stacked, accuracy: measurementAccuracy, "'\(first)' then '\(second)', blockSpacing \(blockSpacing)")
      }
    }
  }

  func test_adjacentTextBlocks_renderInOneTextView() async {
    let document = await renderableDocument(for: "# Title\n\nFirst paragraph.\n\n```\ncode\n```\n\nLast paragraph.")

    let textViews = renderedTextViews(for: [document])[0]

    XCTAssertEqual(textViews.map(\.paragraphContents.string), ["Title\nFirst paragraph.", "Last paragraph."])
  }

  /// When streaming turns a lone heading into a group, SwiftUI must update the
  /// same text view rather than recreate it, so appended words can fade in.
  func test_blockBecomingGroup_keepsItsTextView() async {
    let single = await renderableDocument(for: "# Title")
    let grouped = await renderableDocument(for: "# Title\n\nBody")

    let renders = renderedTextViews(for: [single, grouped])

    XCTAssertEqual(renders.map(\.count), [1, 1])
    XCTAssertTrue(renders[0].first === renders[1].first, "Expected the text view to be reused")
    XCTAssertEqual(renders[1].first?.paragraphContents.string, "Title\nBody")
  }

  // MARK: - Streaming updates

  func test_streamingAppend_keepsSelection() async {
    guard let first = await textGroup("# Title\n\nFirst"), let second = await textGroup("# Title\n\nFirst paragraph") else { return }

    withHostedParagraphView { view in
      view.setParagraphContents(first.content, animatedByWord: false)
      view.selection = NSRange(location: 0, length: 5)

      view.setParagraphContents(second.content, animatedByWord: true)

      XCTAssertEqual(view.displayedText.string, "Title\nFirst paragraph")
      XCTAssertEqual(view.selection, NSRange(location: 0, length: 5), "Appended text must not reset the selection")
    }
  }

  func test_nonAnimatedUpdate_clearsInFlightFades() async {
    guard let first = await textGroup("# Title\n\nFirst"), let second = await textGroup("# Title\n\nFirst paragraph") else { return }

    withHostedParagraphView { view in
      view.setParagraphContents(first.content, animatedByWord: true)
      view.setParagraphContents(second.content, animatedByWord: false)

      let displayed = view.displayedText.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? MDColor
      let source = second.content.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? MDColor
      XCTAssertEqual(displayed, source, "A fade cut short must not leave text translucent")
    }
  }

  // MARK: - Accessibility

  func test_group_exposesOneAccessibilityElementPerBlock() async {
    guard let group = await textGroup("# Title\n\nBody text.") else { return }

    withHostedParagraphView { view in
      view.setParagraphContents(group.content, animatedByWord: false)
      let elements = view.blockElements

      XCTAssertFalse(view.isOneAccessibilityElement, "The blocks are the elements, not the whole text view")
      XCTAssertEqual(elements.map { $0.label }, ["Title", "Body text."])
      XCTAssertEqual(elements.map { $0.isHeading }, [true, false])
      guard elements.count == 2 else { return }
      XCTAssertFalse(elements[0].frame.isEmpty)
      XCTAssertTrue(isAbove(elements[0].frame, elements[1].frame), "Each element must be framed on its own block")
    }
  }

  func test_singleBlock_staysOneAccessibilityElement() async {
    guard case .paragraph(_, let content) = await renderableDocument(for: "Just one paragraph.").renderables.first else {
      return XCTFail("Expected a paragraph")
    }

    withHostedParagraphView { view in
      view.setParagraphContents(content, animatedByWord: false)

      XCTAssertTrue(view.isOneAccessibilityElement)
      XCTAssertTrue(view.blockElements.isEmpty)
    }
  }

  // MARK: - Helpers

  private func measuredHeight(ofBlock block: MarkdownRenderable) -> CGFloat {
    switch block {
    case .heading(_, _, let content), .paragraph(_, let content): return measuredHeight(of: content)
    default: return 0
    }
  }

  private func measuredHeight(of content: NSMutableAttributedString, width: CGFloat = 300) -> CGFloat {
    let view = MDParagraphView()
    view.setParagraphContents(content, animatedByWord: false)
    #if canImport(UIKit)
    return view.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height
    #else
    return view.measureSize(fittingWidth: width).height
    #endif
  }

  #if canImport(UIKit)
  private let measurementAccuracy: CGFloat = 0.01

  /// Whether `upper` sits above `lower`, in view coordinates that grow downwards.
  private func isAbove(_ upper: CGRect, _ lower: CGRect) -> Bool {
    upper.maxY <= lower.minY
  }

  /// Renders each document in turn in the same host and returns the paragraph
  /// text views present after each render.
  private func renderedTextViews(for documents: [RenderableDocument]) -> [[ParagraphUIView]] {
    let host = UIHostingController(rootView: DocumentView(renderableDocument: documents[0]))
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
    window.rootViewController = host
    window.makeKeyAndVisible()
    defer { window.isHidden = true }
    return documents.map { document in
      host.rootView = DocumentView(renderableDocument: document)
      host.view.setNeedsLayout()
      host.view.layoutIfNeeded()
      return host.view.descendants(ofType: ParagraphUIView.self)
    }
  }

  private func withHostedParagraphView(_ body: (ParagraphUIView) -> Void) {
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
    let view = ParagraphUIView(frame: CGRect(x: 0, y: 0, width: 350, height: 400))
    window.addSubview(view)
    window.makeKeyAndVisible()
    defer { window.isHidden = true }
    _ = view.becomeFirstResponder()
    body(view)
  }
  #elseif canImport(AppKit)
  /// Separate views each round their height up to a whole point.
  private let measurementAccuracy: CGFloat = 1

  /// Whether `upper` sits above `lower`, in screen coordinates that grow upwards.
  private func isAbove(_ upper: CGRect, _ lower: CGRect) -> Bool {
    upper.minY >= lower.maxY
  }

  private func renderedTextViews(for documents: [RenderableDocument]) -> [[ParagraphNSView]] {
    let host = NSHostingController(rootView: DocumentView(renderableDocument: documents[0]))
    let window = NSWindow(contentViewController: host)
    window.setContentSize(CGSize(width: 390, height: 844))
    return documents.map { document in
      host.rootView = DocumentView(renderableDocument: document)
      host.view.layoutSubtreeIfNeeded()
      return host.view.descendants(ofType: ParagraphNSView.self)
    }
  }

  private func withHostedParagraphView(_ body: (ParagraphNSView) -> Void) {
    let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 390, height: 844), styleMask: [.titled], backing: .buffered, defer: false)
    let view = ParagraphNSView()
    view.frame = CGRect(x: 0, y: 0, width: 350, height: 400)
    window.contentView?.addSubview(view)
    window.makeFirstResponder(view)
    body(view)
  }
  #endif
}

/// What a text view exposes to accessibility for one block.
private struct BlockElement {
  let label: String?
  let isHeading: Bool
  let frame: CGRect
}

#if canImport(UIKit)
private extension ParagraphUIView {
  var selection: NSRange {
    get { selectedRange }
    set { selectedRange = newValue }
  }
  var displayedText: NSAttributedString { attributedText }
  var isOneAccessibilityElement: Bool { isAccessibilityElement }
  var blockElements: [BlockElement] {
    (accessibilityElements as? [UIAccessibilityElement] ?? []).map {
      BlockElement(label: $0.accessibilityLabel, isHeading: $0.accessibilityTraits.contains(.header), frame: $0.accessibilityFrameInContainerSpace)
    }
  }
}

private extension UIView {
  func descendants<T: UIView>(ofType type: T.Type) -> [T] {
    subviews.flatMap { subview -> [T] in
      ((subview as? T).map { [$0] } ?? []) + subview.descendants(ofType: type)
    }
  }
}
#elseif canImport(AppKit)
private extension ParagraphNSView {
  var selection: NSRange {
    get { selectedRange() }
    set { setSelectedRange(newValue) }
  }
  var displayedText: NSAttributedString { attributedString() }
  var isOneAccessibilityElement: Bool { isAccessibilityElement() }
  var blockElements: [BlockElement] {
    guard !isAccessibilityElement() else { return [] }
    return (accessibilityChildren() as? [NSAccessibilityElement] ?? []).map {
      BlockElement(label: $0.accessibilityLabel(), isHeading: $0.accessibilityRole()?.rawValue == "AXHeading", frame: $0.accessibilityFrame())
    }
  }
}

private extension NSView {
  func descendants<T: NSView>(ofType type: T.Type) -> [T] {
    subviews.flatMap { subview -> [T] in
      ((subview as? T).map { [$0] } ?? []) + subview.descendants(ofType: type)
    }
  }
}
#endif
