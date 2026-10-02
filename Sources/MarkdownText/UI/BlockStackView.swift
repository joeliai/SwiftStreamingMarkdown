//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import UIKit

/// Stacks block views vertically with `spacing` between them. Across updates,
/// a block keeps its view while its id and kind are unchanged, so streamed
/// content only touches the blocks that changed.
final class BlockStackView: UIView, MarkdownLayoutInvalidating {

  private struct Entry {
    let id: String
    let kind: MarkdownRenderable.Kind
    let view: MarkdownBlockView
  }

  var spacing: CGFloat = 0 {
    didSet {
      guard spacing != oldValue else { return }
      invalidateMarkdownLayout()
    }
  }

  private var entries: [Entry] = []
  private var cachedHeight: (width: CGFloat, height: CGFloat)?

  var isEmpty: Bool {
    entries.isEmpty
  }

  func update(renderables: [MarkdownRenderable], context: BlockContext) {
    var reusable = Dictionary(entries.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    var updatedEntries: [Entry] = []
    updatedEntries.reserveCapacity(renderables.count)

    for renderable in renderables {
      let kind = renderable.kind
      if let existing = reusable.removeValue(forKey: renderable.id), existing.kind == kind {
        existing.view.update(with: renderable, context: context)
        updatedEntries.append(existing)
      } else {
        let view = makeBlockView(for: renderable, context: context)
        addSubview(view)
        updatedEntries.append(Entry(id: renderable.id, kind: kind, view: view))
      }
    }

    // Remove every view that wasn't reused, including ones whose id repeated.
    let keptViews = Set(updatedEntries.map { ObjectIdentifier($0.view) })
    for entry in entries where !keptViews.contains(ObjectIdentifier(entry.view)) {
      entry.view.removeFromSuperview()
    }
    entries = updatedEntries
    invalidateMarkdownLayout()
  }

  func height(forWidth width: CGFloat) -> CGFloat {
    if let cachedHeight, cachedHeight.width == width {
      return cachedHeight.height
    }
    var height: CGFloat = 0
    for (index, entry) in entries.enumerated() {
      if index > 0 {
        height += spacing
      }
      height += entry.view.height(forWidth: width)
    }
    cachedHeight = (width, height)
    return height
  }

  override func sizeThatFits(_ size: CGSize) -> CGSize {
    CGSize(width: size.width, height: height(forWidth: size.width))
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    let width = bounds.width
    var y: CGFloat = 0
    for (index, entry) in entries.enumerated() {
      if index > 0 {
        y += spacing
      }
      let height = entry.view.height(forWidth: width)
      entry.view.frame = CGRect(x: 0, y: y, width: width, height: height)
      y += height
    }
  }

  func invalidateMarkdownLayout() {
    cachedHeight = nil
    setNeedsLayout()
  }
}
