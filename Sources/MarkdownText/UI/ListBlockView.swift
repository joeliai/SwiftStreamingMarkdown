//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import UIKit

/// Renders an ordered or unordered (optionally task) list. Each item shows a
/// marker next to its first child, vertically centered on the child's first
/// line; the item's remaining children are stacked below it.
final class ListBlockView: UIView, MarkdownBlockView, MarkdownLayoutInvalidating {

  enum Style: Equatable {
    case ordered
    case unordered(nestedLevel: Int)
  }

  /// Spacing between an item's row and whatever follows it.
  private static let itemSpacing: CGFloat = 8
  /// Room kept free after an item's first child.
  private static let trailingSpace: CGFloat = 8
  /// Width of the column holding an unordered item's bullet or checkbox.
  private static let bulletColumnWidth: CGFloat = 22
  /// Indentation added per nesting level of an unordered list.
  private static let nestedIndent: CGFloat = 8

  private struct FirstChild {
    let id: String
    let kind: MarkdownRenderable.Kind
    let view: MarkdownBlockView
  }

  private final class Item {
    let marker: UIView
    var firstChild: FirstChild?
    /// Distance from the first child's top to the center of its first line.
    var firstLineCenter: CGFloat?
    let nestedBlocks = BlockStackView()

    init(marker: UIView) {
      self.marker = marker
    }
  }

  private struct ItemFrames {
    let marker: CGRect
    let firstChild: CGRect
    let nestedBlocks: CGRect?
  }

  private struct Layout {
    let width: CGFloat
    let frames: [ItemFrames]
    let height: CGFloat
  }

  private var style: Style
  private var items: [Item] = []
  private var cachedLayout: Layout?

  init(style: Style) {
    self.style = style
    super.init(frame: .zero)
  }

  required init?(coder: NSCoder) {
    nil
  }

  // MARK: - Style

  private var leadingInset: CGFloat {
    switch style {
    case .ordered: return 0
    case .unordered(let nestedLevel): return CGFloat(nestedLevel) * Self.nestedIndent
    }
  }

  private var markerSpacing: CGFloat {
    switch style {
    case .ordered: return 11
    case .unordered: return 1
    }
  }

  private func makeMarker() -> UIView {
    let marker: UIView
    switch style {
    case .ordered:
      marker = UILabel()
    case .unordered:
      let symbolView = SymbolMarkerView()
      symbolView.tintColor = UIColor.Theme.Foreground.Primary.Primary450
      marker = symbolView
    }
    marker.isAccessibilityElement = false
    return marker
  }

  private func updateMarker(_ marker: UIView, for item: MarkdownListItem, at index: Int, context: BlockContext) {
    switch style {
    case .ordered:
      guard let label = marker as? UILabel else { return }
      let textStyle = context.config.orderedListStyle
      var attributes: [NSAttributedString.Key: Any] = [
        .font: textStyle.textFonts.font(bold: true),
        .foregroundColor: textStyle.textColor
      ]
      if let kern = textStyle.textFonts.preferredLetterSpacing {
        attributes[.kern] = kern
      }
      label.attributedText = NSAttributedString(string: "\(index + 1).", attributes: attributes)
      label.sizeToFit()
    case .unordered(let nestedLevel):
      guard let symbolView = marker as? SymbolMarkerView else { return }
      let symbolName: String
      let side: CGFloat
      switch item.checkbox {
      case .checked:
        (symbolName, side) = ("checkmark.square.fill", 12)
      case .unchecked:
        (symbolName, side) = ("square", 12)
      case nil:
        (symbolName, side) = (nestedLevel % 2 == 0 ? "circle.fill" : "circle", 4)
      }
      symbolView.setSymbol(named: symbolName)
      symbolView.bounds.size = CGSize(width: side, height: side)
    }
  }

  private func accessibilityLabel(for content: String, at index: Int, item: MarkdownListItem) -> String {
    let label = markdownListAccessibilityLabel(for: content, at: index, length: items.count)
    switch item.checkbox {
    case .checked: return "\(label), \(String.taskListItemChecked)"
    case .unchecked: return "\(label), \(String.taskListItemUnchecked)"
    case .none: return label
    }
  }

  // MARK: - MarkdownBlockView

  func update(with renderable: MarkdownRenderable, context: BlockContext) {
    let listItems: [MarkdownListItem]
    switch renderable {
    case .orderedList(_, let orderedItems):
      listItems = orderedItems
    case .unorderedList(_, let unorderedItems, let nestedLevel):
      listItems = unorderedItems
      style = .unordered(nestedLevel: nestedLevel)
    default:
      return
    }

    while items.count > listItems.count {
      let removed = items.removeLast()
      removed.marker.removeFromSuperview()
      removed.firstChild?.view.removeFromSuperview()
      removed.nestedBlocks.removeFromSuperview()
    }
    while items.count < listItems.count {
      let item = Item(marker: makeMarker())
      addSubview(item.marker)
      addSubview(item.nestedBlocks)
      items.append(item)
    }

    for (index, listItem) in listItems.enumerated() {
      let item = items[index]
      updateMarker(item.marker, for: listItem, at: index, context: context)
      updateFirstChild(of: item, with: listItem.children.first, listItem: listItem, at: index, context: context)
      item.nestedBlocks.spacing = context.config.blockSpacing
      item.nestedBlocks.update(renderables: Array(listItem.children.dropFirst()), context: context)
    }
    invalidateMarkdownLayout()
  }

  private func updateFirstChild(
    of item: Item,
    with renderable: MarkdownRenderable?,
    listItem: MarkdownListItem,
    at index: Int,
    context: BlockContext
  ) {
    guard let renderable else {
      item.firstChild?.view.removeFromSuperview()
      item.firstChild = nil
      item.firstLineCenter = nil
      return
    }

    if let current = item.firstChild, current.id == renderable.id, current.kind == renderable.kind {
      current.view.update(with: renderable, context: context)
    } else {
      item.firstChild?.view.removeFromSuperview()
      let view = makeBlockView(for: renderable, context: context)
      addSubview(view)
      item.firstChild = FirstChild(id: renderable.id, kind: renderable.kind, view: view)
    }

    switch renderable {
    case .paragraph(_, let contents):
      item.firstLineCenter = firstLineFont(of: contents).lineHeight / 2
      (item.firstChild?.view as? TextBlockView)?.accessibilityLabelOverride =
        accessibilityLabel(for: contents.string, at: index, item: listItem)
    case .heading(_, _, let contents):
      item.firstLineCenter = firstLineFont(of: contents).lineHeight / 2
    default:
      item.firstLineCenter = nil
    }
  }

  func height(forWidth width: CGFloat) -> CGFloat {
    layout(forWidth: width).height
  }

  override func sizeThatFits(_ size: CGSize) -> CGSize {
    CGSize(width: size.width, height: height(forWidth: size.width))
  }

  func invalidateMarkdownLayout() {
    cachedLayout = nil
    setNeedsLayout()
  }

  // MARK: - Layout

  override func layoutSubviews() {
    super.layoutSubviews()
    let frames = layout(forWidth: bounds.width).frames
    for (item, itemFrames) in zip(items, frames) {
      item.marker.frame = itemFrames.marker
      item.firstChild?.view.frame = itemFrames.firstChild
      item.nestedBlocks.isHidden = itemFrames.nestedBlocks == nil
      item.nestedBlocks.frame = itemFrames.nestedBlocks ?? .zero
    }
  }

  private func layout(forWidth width: CGFloat) -> Layout {
    if let cachedLayout, cachedLayout.width == width {
      return cachedLayout
    }

    let inset = leadingInset
    var frames: [ItemFrames] = []
    var y: CGFloat = 0
    for (index, item) in items.enumerated() {
      if index > 0 {
        y += Self.itemSpacing
      }

      let markerSize = item.marker.bounds.size
      let markerX: CGFloat
      let contentX: CGFloat
      switch style {
      case .ordered:
        markerX = inset
        contentX = inset + markerSize.width + markerSpacing
      case .unordered:
        markerX = inset + (Self.bulletColumnWidth - markerSize.width) / 2
        contentX = inset + Self.bulletColumnWidth + markerSpacing
      }
      let contentWidth = max(0, width - contentX - markerSpacing - Self.trailingSpace)
      let contentHeight = item.firstChild?.view.height(forWidth: contentWidth) ?? 0

      // Center the marker on the first line of text; when the marker is taller
      // than that line, push the content down instead of the marker up.
      let anchor = item.firstLineCenter ?? markerSize.height / 2
      var markerY = anchor - markerSize.height / 2
      var contentY: CGFloat = 0
      if markerY < 0 {
        contentY = -markerY
        markerY = 0
      }
      let rowHeight = max(contentY + contentHeight, markerY + markerSize.height)

      let markerFrame = CGRect(origin: CGPoint(x: markerX, y: y + markerY), size: markerSize)
      let contentFrame = CGRect(x: contentX, y: y + contentY, width: contentWidth, height: contentHeight)
      y += rowHeight

      var nestedFrame: CGRect?
      if !item.nestedBlocks.isEmpty {
        y += Self.itemSpacing
        let nestedWidth = max(0, width - inset)
        let nestedHeight = item.nestedBlocks.height(forWidth: nestedWidth)
        nestedFrame = CGRect(x: inset, y: y, width: nestedWidth, height: nestedHeight)
        y += nestedHeight
      }
      frames.append(ItemFrames(marker: markerFrame, firstChild: contentFrame, nestedBlocks: nestedFrame))
    }
    let layout = Layout(width: width, frames: frames, height: y)
    cachedLayout = layout
    return layout
  }

  // MARK: - SymbolMarkerView

  /// Draws an SF Symbol stretched so its glyph fills the bounds, like SwiftUI's
  /// `Image(systemName:).resizable()`. A `UIImageView` would stretch the symbol
  /// image's whole canvas, including the padding around the glyph, so the
  /// glyph would come out smaller than the box.
  private final class SymbolMarkerView: UIView {

    private static let wholeImage = CGRect(x: 0, y: 0, width: 1, height: 1)
    /// Glyph bounds as fractions of the symbol image's size, by symbol name.
    private static var glyphRects: [String: CGRect] = [:]

    private var symbolName: String?
    private var image: UIImage?
    private var glyphRect = SymbolMarkerView.wholeImage

    override init(frame: CGRect) {
      super.init(frame: frame)
      isOpaque = false
      contentMode = .redraw
    }

    required init?(coder: NSCoder) {
      nil
    }

    func setSymbol(named name: String) {
      guard name != symbolName, let image = UIImage(systemName: name) else { return }
      symbolName = name
      self.image = image
      glyphRect = Self.glyphRect(of: image, named: name)
      setNeedsDisplay()
    }

    override func tintColorDidChange() {
      super.tintColorDidChange()
      setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
      guard let image, let context = UIGraphicsGetCurrentContext() else { return }
      let imageSize = CGSize(width: bounds.width / glyphRect.width, height: bounds.height / glyphRect.height)
      // Scale through the context: `draw(in:)` with a scaled rect snaps the
      // symbol to the pixel grid, which can be off by a pixel.
      context.translateBy(x: -glyphRect.minX * imageSize.width, y: -glyphRect.minY * imageSize.height)
      context.scaleBy(x: imageSize.width / image.size.width, y: imageSize.height / image.size.height)
      image.withTintColor(tintColor).draw(in: CGRect(origin: .zero, size: image.size))
    }

    private static func glyphRect(of image: UIImage, named name: String) -> CGRect {
      if let glyphRect = glyphRects[name] {
        return glyphRect
      }
      let glyphRect = measureGlyphRect(of: image) ?? wholeImage
      glyphRects[name] = glyphRect
      return glyphRect
    }

    /// UIKit has no API for a symbol's glyph bounds, so this measures the
    /// opaque area of a high-resolution rendering of `image`.
    private static func measureGlyphRect(of image: UIImage) -> CGRect? {
      let scale: CGFloat = 20
      let width = Int((image.size.width * scale).rounded(.up))
      let height = Int((image.size.height * scale).rounded(.up))
      guard width > 0, height > 0,
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
      UIGraphicsPushContext(context)
      image.withTintColor(.black).draw(in: CGRect(origin: .zero, size: image.size))
      UIGraphicsPopContext()

      let pixels = data.assumingMemoryBound(to: UInt8.self)
      let bytesPerRow = context.bytesPerRow
      var minX = width, minY = height, maxX = -1, maxY = -1
      for y in 0..<height {
        for x in 0..<width where pixels[y * bytesPerRow + x * 4 + 3] > 127 {
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
        x: CGFloat(minX) / scale / image.size.width,
        y: CGFloat(minY) / scale / image.size.height,
        width: CGFloat(maxX - minX + 1) / scale / image.size.width,
        height: CGFloat(maxY - minY + 1) / scale / image.size.height
      )
    }
  }
}

/// The font used by the first line of `attributedString`: a leading citation
/// pill's own font, else the first font attribute, else the base font.
func firstLineFont(of attributedString: NSAttributedString) -> MDFont {
  guard attributedString.length > 0 else {
    return Typography.base.mdFont
  }
  if let citation = attributedString.attribute(.attachment, at: 0, effectiveRange: nil) as? InlineCitationAttachment {
    return citation.font
  }
  if let font = attributedString.attribute(.font, at: 0, effectiveRange: nil) as? MDFont {
    return font
  }
  var found: MDFont?
  attributedString.enumerateAttribute(.font, in: NSRange(location: 0, length: attributedString.length)) { value, _, stop in
    if let font = value as? MDFont {
      found = font
      stop.pointee = true
    }
  }
  return found ?? Typography.base.mdFont
}

func markdownListAccessibilityLabel(
  for item: String,
  at index: Int,
  length: Int
) -> String {
  String.markdownListItem(length: length, index: index + 1, item: item)
}
