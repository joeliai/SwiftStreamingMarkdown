//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

@testable import SwiftStreamingMarkdown
import UIKit
import XCTest

/// Insets between a test cell's edges and its Markdown view.
private let testCellInsets = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)

/// Verifies that the Markdown views work as the content of self-sizing
/// `UICollectionView` and `UITableView` cells, including when their content
/// grows after the cell was first sized.
@MainActor
final class SelfSizingCellTests: XCTestCase {

  private static let width: CGFloat = 390

  private let parser = MarkdownParserImpl()

  // MARK: - UICollectionView

  func testCollectionViewCellsSizeToTheirMarkdownAndGrowWhileStreaming() async throws {
    let dataSource = DocumentDataSource(documents: [
      await parser.parse(text: "Short reply.", config: .default),
      await parser.parse(text: richMarkdownSample, config: .default),
      await parser.parse(text: "A streaming reply that is still", config: .default)
    ])
    let collectionView = makeCollectionView(dataSource: dataSource)
    let window = UIWindow(frame: collectionView.frame)
    window.addSubview(collectionView)
    window.isHidden = false
    defer { window.isHidden = true }

    await settleLayout(of: collectionView)
    for (index, document) in dataSource.documents.enumerated() {
      let cell = try XCTUnwrap(collectionView.cellForItem(at: IndexPath(item: index, section: 0)))
      assertCellHeight(of: cell, matches: document, index: index)
    }

    // Stream more content into the last, visible cell without reloading it.
    let streamingCell = try XCTUnwrap(collectionView.cellForItem(at: IndexPath(item: 2, section: 0)) as? DocumentCell)
    let heightBeforeStreaming = streamingCell.frame.height
    let grown = await parser.parse(text: Self.grownStreamingReply, config: .default)
    dataSource.documents[2] = grown
    streamingCell.documentView.renderableDocument = grown

    await settleLayout(of: collectionView)
    XCTAssertGreaterThan(streamingCell.frame.height, heightBeforeStreaming)
    assertCellHeight(of: streamingCell, matches: grown, index: 2)
  }

  // MARK: - UITableView

  func testTableViewCellsAreInvalidatedWhenMarkdownIsParsedAndGrows() async throws {
    let texts = ["Short reply.", richMarkdownSample, "A streaming reply that is still"]
    let dataSource = MarkdownTextDataSource(texts: texts)
    let tableView = makeTableView(dataSource: dataSource)
    let window = UIWindow(frame: tableView.frame)
    window.addSubview(tableView)
    window.isHidden = false
    defer { window.isHidden = true }

    // `MarkdownView` parses asynchronously, so each cell is first sized while
    // still empty and must be invalidated once its Markdown has been parsed.
    await settleLayout(of: tableView)
    let cells = try texts.indices.map { row in
      try XCTUnwrap(tableView.cellForRow(at: IndexPath(row: row, section: 0)) as? MarkdownTableCell)
    }
    await waitUntil {
      cells.allSatisfy { $0.markdownView.descendants(of: DocumentView.self).first?.renderableDocument.isEmpty == false }
    }
    for (row, cell) in cells.enumerated() {
      XCTAssertGreaterThan(cell.intrinsicContentSizeInvalidationCount, 0, "Parsing must invalidate cell \(row)")
    }
    await applyPendingSelfSizingUpdates(to: tableView)
    for (row, text) in texts.enumerated() {
      assertCellHeight(of: cells[row], matches: await parser.parse(text: text, config: .default), index: row)
    }

    // Grow the last, visible cell without reloading it.
    let streamingCell = cells[2]
    let heightBeforeStreaming = streamingCell.frame.height
    streamingCell.intrinsicContentSizeInvalidationCount = 0
    streamingCell.markdownView.text = Self.grownStreamingReply
    await waitUntil {
      streamingCell.markdownView.descendants(of: DocumentView.self).first?.renderableDocument.plainText.contains("Release notes") == true
    }
    XCTAssertGreaterThan(streamingCell.intrinsicContentSizeInvalidationCount, 0, "Growing content must invalidate its cell")

    await applyPendingSelfSizingUpdates(to: tableView)
    XCTAssertGreaterThan(streamingCell.frame.height, heightBeforeStreaming)
    assertCellHeight(of: streamingCell, matches: await parser.parse(text: Self.grownStreamingReply, config: .default), index: 2)
  }

  // MARK: - Helpers

  private static let grownStreamingReply = "A streaming reply that is still growing.\n\n" + richMarkdownSample

  private func makeCollectionView(dataSource: DocumentDataSource) -> UICollectionView {
    let layout = UICollectionViewCompositionalLayout { _, _ in
      let size = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(44))
      let group = NSCollectionLayoutGroup.vertical(layoutSize: size, subitems: [NSCollectionLayoutItem(layoutSize: size)])
      return NSCollectionLayoutSection(group: group)
    }
    let collectionView = UICollectionView(
      frame: CGRect(x: 0, y: 0, width: Self.width, height: 3000),
      collectionViewLayout: layout
    )
    collectionView.register(DocumentCell.self, forCellWithReuseIdentifier: DocumentCell.reuseIdentifier)
    collectionView.dataSource = dataSource
    return collectionView
  }

  private func makeTableView(dataSource: MarkdownTextDataSource) -> UITableView {
    let tableView = UITableView(frame: CGRect(x: 0, y: 0, width: Self.width, height: 3000), style: .plain)
    // Without separators the content view spans the whole cell height.
    tableView.separatorStyle = .none
    tableView.rowHeight = UITableView.automaticDimension
    tableView.estimatedRowHeight = 44
    tableView.register(MarkdownTableCell.self, forCellReuseIdentifier: MarkdownTableCell.reuseIdentifier)
    tableView.dataSource = dataSource
    return tableView
  }

  /// Applies the cell resizes `UITableView` has scheduled. In an app, the table
  /// view applies them on its own after a cell invalidates its intrinsic content
  /// size, but XCTest runs without a window scene, where those deferred updates
  /// never run.
  private func applyPendingSelfSizingUpdates(to tableView: UITableView) async {
    await settleLayout(of: tableView)
    tableView.performBatchUpdates(nil)
    await settleLayout(of: tableView)
  }

  private func assertCellHeight(
    of cell: UIView,
    matches document: RenderableDocument,
    index: Int,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    let contentWidth = Self.width - testCellInsets.left - testCellInsets.right
    let contentHeight = DocumentView(renderableDocument: document)
      .sizeThatFits(CGSize(width: contentWidth, height: CGFloat.greatestFiniteMagnitude))
      .height
    XCTAssertGreaterThan(contentHeight, 0, file: file, line: line)
    XCTAssertEqual(
      cell.frame.height,
      contentHeight + testCellInsets.top + testCellInsets.bottom,
      accuracy: 1,
      "Cell \(index) should size to its rendered Markdown",
      file: file,
      line: line
    )
  }
}

extension UIView {
  /// Pins `content` inside this view with the test cells' insets.
  fileprivate func pinTestContent(_ content: UIView) {
    let insets = testCellInsets
    content.translatesAutoresizingMaskIntoConstraints = false
    addSubview(content)
    NSLayoutConstraint.activate([
      content.topAnchor.constraint(equalTo: topAnchor, constant: insets.top),
      content.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -insets.bottom),
      content.leadingAnchor.constraint(equalTo: leadingAnchor, constant: insets.left),
      content.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -insets.right)
    ])
  }
}

/// A collection view cell that pins a `DocumentView` inside its content view.
private final class DocumentCell: UICollectionViewCell {
  static let reuseIdentifier = "DocumentCell"

  let documentView = DocumentView()

  override init(frame: CGRect) {
    super.init(frame: frame)
    contentView.pinTestContent(documentView)
  }

  required init?(coder: NSCoder) {
    nil
  }

  override func prepareForReuse() {
    super.prepareForReuse()
    documentView.prepareForReuse()
  }
}

private final class DocumentDataSource: NSObject, UICollectionViewDataSource {
  var documents: [RenderableDocument]

  init(documents: [RenderableDocument]) {
    self.documents = documents
  }

  func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    documents.count
  }

  func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: DocumentCell.reuseIdentifier, for: indexPath)
    (cell as? DocumentCell)?.documentView.renderableDocument = documents[indexPath.item]
    return cell
  }
}

/// A table view cell that pins a `MarkdownView` inside its content view and
/// counts how often it is asked to resize.
private final class MarkdownTableCell: UITableViewCell {
  static let reuseIdentifier = "MarkdownTableCell"

  let markdownView = MarkdownView()
  var intrinsicContentSizeInvalidationCount = 0

  override func invalidateIntrinsicContentSize() {
    intrinsicContentSizeInvalidationCount += 1
    super.invalidateIntrinsicContentSize()
  }

  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    contentView.pinTestContent(markdownView)
  }

  required init?(coder: NSCoder) {
    nil
  }

  override func prepareForReuse() {
    super.prepareForReuse()
    markdownView.prepareForReuse()
  }
}

private final class MarkdownTextDataSource: NSObject, UITableViewDataSource {
  let texts: [String]

  init(texts: [String]) {
    self.texts = texts
  }

  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    texts.count
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: MarkdownTableCell.reuseIdentifier, for: indexPath)
    (cell as? MarkdownTableCell)?.markdownView.text = texts[indexPath.row]
    return cell
  }
}
