//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

//  SnapshotTestCase is a utility class extending XCTestCase.
//
//  By default, it registers a diff tool ("diff-image") to assist in comparing mismatched snapshots.
//  You can toggle recording behavior by setting `isRecording` to `true` or `false` in `setUp()`.
//
import SnapshotTesting
import UIKit
import XCTest
@testable import SwiftStreamingMarkdown

open class SnapshotTestCase: XCTestCase {
  override open func setUp() {
    super.setUp()
    SnapshotTesting.diffTool = "diff-image"
    ParagraphViewCache.shared.clearCache()
    // isRecording = true
  }

  /// Snapshots the view built by `makeView`, hosted in a `CanvasViewController`,
  /// once per device variant. A fresh view is built for every variant.
  /// - Parameters:
  ///   - insets: Insets applied inside the safe area. Defaults to none.
  ///   - verticalAlignment: Pins the view to the top of the safe area or centers it.
  ///   - variants: Device variants to be tested. Defaults to the standard collection of device variants.
  ///   - testName: The name of the test in which failure occurred. Defaults to the function name of the test case in which this function was called.
  ///   - file: The file in which failure occurred. Defaults to the file name of the test case in which this function was called.
  ///   - line: The line number on which failure occurred. Defaults to the line number on which this function was called.
  ///   - makeView: Builds the view under test.
  @MainActor
  func assert(
    insets: UIEdgeInsets = .zero,
    verticalAlignment: CanvasViewController.VerticalAlignment = .top,
    variants: [IOSVariant] = .standard(precision: 0.99, perceptualPrecision: 1.00),
    testName: String = #function,
    file: StaticString = #file,
    line: UInt = #line,
    makeView: () -> UIView
  ) {
    for variant in variants {
      let viewController = CanvasViewController(content: makeView(), insets: insets, verticalAlignment: verticalAlignment)
      assertSnapshot(
        of: viewController,
        as: variant.snapshot,
        named: variant.name,
        file: file,
        testName: testName,
        line: line
      )
    }
  }

  /// Snapshots a `DocumentView` rendering `renderableDocument` with 24-point
  /// horizontal insets.
  @MainActor
  func assertDocument(
    _ renderableDocument: RenderableDocument,
    config: MarkdownRenderConfig = .default,
    testName: String = #function,
    file: StaticString = #file,
    line: UInt = #line
  ) {
    assert(insets: UIEdgeInsets(top: 0, left: 24, bottom: 0, right: 24), testName: testName, file: file, line: line) {
      DocumentView(renderableDocument: renderableDocument, config: config)
    }
  }

  /// Snapshots the block view that renders `renderable` on its own.
  @MainActor
  func assertBlock(
    _ renderable: MarkdownRenderable,
    config: MarkdownRenderConfig = .default,
    insets: UIEdgeInsets = .zero,
    verticalAlignment: CanvasViewController.VerticalAlignment = .top,
    testName: String = #function,
    file: StaticString = #file,
    line: UInt = #line,
    configure: (MarkdownBlockView) -> Void = { _ in }
  ) {
    assert(insets: insets, verticalAlignment: verticalAlignment, testName: testName, file: file, line: line) {
      let view = makeBlockView(for: renderable, context: BlockContext(config: config, controller: nil))
      configure(view)
      return view
    }
  }
}
