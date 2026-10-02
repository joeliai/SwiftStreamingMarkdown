//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

@testable import SwiftStreamingMarkdown
import UIKit
import XCTest

@MainActor
final class TableViewTests: SnapshotTestCase {

  // MARK: - Tests

  func testTableView() throws {
    assertTable(headings: tableViewHeadingMock, rows: tableViewRowsMock)
  }

  func testTableViewLongText() throws {
    assertTable(headings: tableViewHeadingMock, rows: rows(boldText: false))
  }

  func testTableViewLongTextWithCustomMaxWidth() throws {
    assertTable(
      headings: tableViewHeadingMock,
      rows: rows(boldText: false),
      columnMaxWidths: [0: 300, tableViewHeadingMock.count - 1: 250]
    )
  }

  func testTableViewBoldText() throws {
    let headings = [
      bold("City"),
      bold("Cost of Living"),
      bold("Job Opportunities"),
      bold("Safety"),
      bold("Access to Nature")
    ]

    assertTable(headings: headings, rows: rows(boldText: true))
  }

  // MARK: - Helpers

  /// Snapshots a table vertically centered in the safe area.
  private func assertTable(
    headings: [NSMutableAttributedString],
    rows: [[NSMutableAttributedString]],
    columnMaxWidths: [Int: CGFloat] = [:],
    testName: String = #function,
    file: StaticString = #file,
    line: UInt = #line
  ) {
    assertBlock(
      .table(id: "table", headers: headings, rows: rows, rawMarkdown: ""),
      verticalAlignment: .center,
      testName: testName,
      file: file,
      line: line
    ) { view in
      (view as? TableView)?.columnMaxWidths = columnMaxWidths
    }
  }

  private func bold(_ text: String) -> NSMutableAttributedString {
    NSMutableAttributedString(string: text, attributes: [.font: UIFont.boldSystemFont(ofSize: 17)])
  }

  private var tableViewHeadingMock: [NSMutableAttributedString] {
    [
      NSMutableAttributedString(string: "Table Heading"),
      NSMutableAttributedString(string: "heading2"),
      NSMutableAttributedString(string: "heading3"),
      NSMutableAttributedString(string: "heading4"),
      NSMutableAttributedString(string: "heading5")
    ]
  }

  private var tableViewRowsMock: [[NSMutableAttributedString]] {
    [
      ["row1-1 cell Dragon", "Table body", "row1-3 cell", "row1-4 cell", "row1-5 cell"],
      ["row2-1 cell", "row2-2 cell", "row2-3 cell", "row2-4 cell", "row2-5 cell"],
      ["row3-1 cell", "row3-2 cell", "row3-3 cell", "row3-4 cell", "row3-5 cell"]
    ].map { row in row.map { NSMutableAttributedString(string: $0) } }
  }

  private func rows(boldText: Bool = false) -> [[NSMutableAttributedString]] {
    let longText = "This is a very long row, This is a very long row, This is a very long row."
    return [
      [
        boldText ? bold("Sacramento") : NSMutableAttributedString(string: longText),
        NSMutableAttributedString(string: "Moderate"),
        NSMutableAttributedString(string: "High"),
        NSMutableAttributedString(string: "Moderate"),
        NSMutableAttributedString(string: "Excellent")
      ],
      [
        boldText ? bold("San Ramon") : NSMutableAttributedString(string: "row2-1 cell"),
        NSMutableAttributedString(string: "High"),
        NSMutableAttributedString(string: "High"),
        NSMutableAttributedString(string: "Very High"),
        NSMutableAttributedString(string: "Good")
      ],
      [
        boldText ? bold("Danville") : NSMutableAttributedString(string: longText),
        NSMutableAttributedString(string: "High"),
        NSMutableAttributedString(string: "Moderate"),
        NSMutableAttributedString(string: "Very High"),
        NSMutableAttributedString(string: "Excellent")
      ]
    ]
  }
}
