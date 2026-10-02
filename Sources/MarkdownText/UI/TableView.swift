//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import UIKit

/// Renders a Markdown table inside a horizontal scroll view. Tapping the table
/// reveals copy and download actions that are routed to the
/// `MarkdownListener`.
final class TableView: UIView, MarkdownBlockView, MarkdownLayoutInvalidating {

  private static let defaultMaxColumnWidth: CGFloat = 200
  private static let cornerRadius: CGFloat = 12
  private static let borderWidth: CGFloat = 1
  private static let actionsTopSpacing: CGFloat = 8
  private static let actionButtonSide: CGFloat = 32
  private static let fallbackRowHeight: CGFloat = 44

  private struct Layout {
    let columnWidths: [CGFloat]
    let rowHeights: [CGFloat]

    var gridSize: CGSize {
      CGSize(width: columnWidths.reduce(0, +), height: rowHeights.reduce(0, +))
    }
  }

  /// Per-column width caps, keyed by column index. Columns without an entry are
  /// capped at 200 points, or at an even share of the visible width when that
  /// is larger.
  var columnMaxWidths: [Int: CGFloat] = [:] {
    didSet { invalidateMarkdownLayout() }
  }

  private let scrollView = UIScrollView()
  private let gridView = UIView()
  private let copyButton = TableActionButton(imageName: "Copy", pressedImageName: "CopyFilled")
  private let downloadButton = TableActionButton(imageName: "downloadArrow", pressedImageName: nil)
  private lazy var tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(toggleActions))

  /// Cells in row-major order; row 0 is the header row.
  private var cells: [[TableCellView]] = []
  private var rawMarkdown = ""
  private var tableStyle = MarkdownRenderConfig.defaultTableStyle
  private weak var controller: MarkdownController?
  private var isExpanded = false
  private var cachedLayout: (width: CGFloat, layout: Layout)?

  init() {
    super.init(frame: .zero)
    scrollView.showsHorizontalScrollIndicator = false
    scrollView.showsVerticalScrollIndicator = false
    scrollView.alwaysBounceVertical = false
    scrollView.addGestureRecognizer(tapRecognizer)
    addSubview(scrollView)

    gridView.layer.cornerRadius = Self.cornerRadius
    gridView.layer.cornerCurve = .continuous
    gridView.layer.borderWidth = Self.borderWidth
    gridView.layer.masksToBounds = true
    scrollView.addSubview(gridView)

    copyButton.accessibilityLabel = String.codeCopyLabel
    copyButton.addTarget(self, action: #selector(copyTable), for: .touchUpInside)
    downloadButton.accessibilityLabel = String.tableDownloadLabel
    downloadButton.addTarget(self, action: #selector(downloadTable), for: .touchUpInside)
    for button in [copyButton, downloadButton] {
      button.isHidden = true
      button.alpha = 0
      addSubview(button)
    }
  }

  required init?(coder: NSCoder) {
    nil
  }

  // MARK: - MarkdownBlockView

  func update(with renderable: MarkdownRenderable, context: BlockContext) {
    guard case .table(_, let headers, let rows, let rawMarkdown) = renderable else { return }
    self.rawMarkdown = rawMarkdown
    self.controller = context.controller
    tableStyle = context.config.tableStyle
    tapRecognizer.isEnabled = context.controller != nil
    copyButton.tintColor = tableStyle.actionButtonColor
    downloadButton.tintColor = tableStyle.actionButtonColor

    let contentRows: [[NSAttributedString]] = [headers] + rows
    let columnCount = headers.count
    let animatesNewCells = context.config.shouldAnimateText

    // Drop rows and columns that no longer exist.
    while cells.count > contentRows.count {
      cells.removeLast().forEach { $0.removeFromSuperview() }
    }
    for rowIndex in cells.indices where cells[rowIndex].count > columnCount {
      cells[rowIndex][columnCount...].forEach { $0.removeFromSuperview() }
      cells[rowIndex].removeLast(cells[rowIndex].count - columnCount)
    }

    for (rowIndex, rowContents) in contentRows.enumerated() {
      if rowIndex == cells.count {
        cells.append([])
      }
      let isHeader = rowIndex == 0
      for (columnIndex, content) in rowContents.enumerated() {
        let themed = themedContent(content, isHeader: isHeader)
        let position = String.itemPositionInTable(
          rowIndex: rowIndex + 1,
          totalRow: contentRows.count,
          columnIndex: columnIndex + 1,
          totalColumn: columnCount
        )
        if columnIndex < cells[rowIndex].count, cells[rowIndex][columnIndex].canDisplay(themed) {
          cells[rowIndex][columnIndex].update(content: themed, accessibilityPosition: position, context: context)
        } else {
          let cell = TableCellView(content: themed)
          cell.update(content: themed, accessibilityPosition: position, context: context)
          if animatesNewCells {
            cell.fadeIn()
          }
          gridView.addSubview(cell)
          if columnIndex < cells[rowIndex].count {
            cells[rowIndex][columnIndex].removeFromSuperview()
            cells[rowIndex][columnIndex] = cell
          } else {
            cells[rowIndex].append(cell)
          }
        }
      }
    }

    for (rowIndex, row) in cells.enumerated() {
      for (columnIndex, cell) in row.enumerated() {
        cell.configureChrome(
          isHeader: rowIndex == 0,
          showsBottomBorder: rowIndex == 0 || rowIndex < cells.count - 1,
          showsTrailingBorder: columnIndex < columnCount - 1,
          style: tableStyle
        )
      }
    }
    invalidateMarkdownLayout()
  }

  func height(forWidth width: CGFloat) -> CGFloat {
    let gridHeight = layout(forWidth: width).gridSize.height
    return isExpanded ? gridHeight + Self.actionsTopSpacing + Self.actionButtonSide : gridHeight
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
    let layout = layout(forWidth: bounds.width)
    let gridSize = layout.gridSize
    scrollView.frame = CGRect(x: 0, y: 0, width: bounds.width, height: gridSize.height)
    scrollView.contentSize = gridSize
    gridView.frame = CGRect(origin: .zero, size: gridSize)
    gridView.layer.borderColor = tableStyle.borderColor.resolvedColor(with: traitCollection).cgColor

    var y: CGFloat = 0
    for (rowIndex, row) in cells.enumerated() {
      var x: CGFloat = 0
      let rowHeight = layout.rowHeights[rowIndex]
      for (columnIndex, cell) in row.enumerated() {
        let columnWidth = layout.columnWidths[columnIndex]
        cell.frame = CGRect(x: x, y: y, width: columnWidth, height: rowHeight)
        x += columnWidth
      }
      y += rowHeight
    }

    let actionsY = gridSize.height + Self.actionsTopSpacing
    let side = Self.actionButtonSide
    copyButton.frame = CGRect(x: 0, y: actionsY, width: side, height: side)
    downloadButton.frame = CGRect(x: side, y: actionsY, width: side, height: side)
  }

  override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
      gridView.layer.borderColor = tableStyle.borderColor.resolvedColor(with: traitCollection).cgColor
    }
  }

  private func layout(forWidth width: CGFloat) -> Layout {
    if let cachedLayout, cachedLayout.width == width {
      return cachedLayout.layout
    }
    let columnCount = cells.first?.count ?? 0
    guard columnCount > 0 else {
      let layout = Layout(columnWidths: [], rowHeights: Array(repeating: 0, count: cells.count))
      cachedLayout = (width, layout)
      return layout
    }

    // A column is as wide as its widest cell, capped at the larger of its
    // maximum width and an even share of the visible width.
    let averageWidth = width / CGFloat(columnCount)
    var columnWidths = Array(repeating: CGFloat(0), count: columnCount)
    for columnIndex in 0..<columnCount {
      let maxWidth = max(averageWidth, columnMaxWidths[columnIndex] ?? Self.defaultMaxColumnWidth)
      let widest = cells.map { $0[columnIndex].naturalWidth }.max() ?? 0
      columnWidths[columnIndex] = min(widest, maxWidth)
    }

    let rowHeights: [CGFloat] = cells.map { row in
      let cellHeights: [CGFloat] = zip(row, columnWidths).map { cell, columnWidth in
        let height = cell.height(forWidth: columnWidth)
        return height.isFinite ? height : Self.fallbackRowHeight
      }
      return cellHeights.max() ?? 0
    }

    let layout = Layout(columnWidths: columnWidths, rowHeights: rowHeights)
    cachedLayout = (width, layout)
    return layout
  }

  // MARK: - Content

  /// Applies the table's text color to runs that don't carry their own color.
  /// Cells that contain both text and citations also get the citation
  /// baseline offset that paragraphs receive while parsing.
  private func themedContent(_ content: NSAttributedString, isHeader: Bool) -> NSAttributedString {
    let themed = NSMutableAttributedString(attributedString: content)
    let fullRange = NSRange(location: 0, length: themed.length)
    let themeColor = isHeader ? tableStyle.headerTextColor : tableStyle.regularTextColor
    themed.enumerateAttribute(.foregroundColor, in: fullRange) { existingColor, range, _ in
      if existingColor == nil {
        themed.addAttribute(.foregroundColor, value: themeColor, range: range)
      }
    }

    var citationRanges: [NSRange] = []
    var containsOtherContent = false
    themed.enumerateAttributes(in: fullRange) { attributes, range, _ in
      guard range.length > 0 else { return }
      if let citation = attributes[.attachment] as? InlineCitationAttachment, citation.citationData != nil {
        citationRanges.append(range)
      } else {
        containsOtherContent = true
      }
    }
    if containsOtherContent, !citationRanges.isEmpty {
      let baselineOffset = Typography.base.mdFont.descender
      for range in citationRanges {
        themed.addAttribute(.baselineOffset, value: baselineOffset, range: range)
      }
    }
    return themed
  }

  // MARK: - Actions

  @objc private func toggleActions() {
    isExpanded.toggle()
    let buttons = [copyButton, downloadButton]
    if isExpanded {
      buttons.forEach { $0.isHidden = false }
    }
    UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseInOut, .beginFromCurrentState]) {
      buttons.forEach { $0.alpha = self.isExpanded ? 1 : 0 }
    } completion: { _ in
      buttons.forEach { $0.isHidden = !self.isExpanded }
    }
    setNeedsMarkdownLayout()
  }

  @objc private func copyTable() {
    controller?.onTableCopyTap(content: rawMarkdown)
    copyButton.playPressFeedback()
  }

  @objc private func downloadTable() {
    controller?.onTableDownloadTap(content: rawMarkdown)
  }
}

// MARK: - Cell

/// A single table cell: its text inset by 12 points, plus its share of the
/// grid lines along its bottom and trailing edges.
private final class TableCellView: UIView, MarkdownLayoutInvalidating {

  private static let padding: CGFloat = 12
  /// Room kept free after the text.
  private static let trailingSpace: CGFloat = 8
  /// Width used to measure a cell's text without wrapping.
  private static let unconstrainedWidth: CGFloat = 10_000

  private enum Content {
    case label(UILabel)
    case paragraph(ParagraphUIView)

    var view: UIView {
      switch self {
      case .label(let label): return label
      case .paragraph(let paragraph): return paragraph
      }
    }
  }

  private let content: Content
  private let bottomBorder = UIView()
  private let trailingBorder = UIView()
  private var cachedNaturalWidth: CGFloat?
  private var cachedHeight: (width: CGFloat, height: CGFloat)?

  init(content: NSAttributedString) {
    if Self.needsTextView(content) {
      self.content = .paragraph(ParagraphUIView())
    } else {
      let label = UILabel()
      label.numberOfLines = 0
      label.lineBreakMode = .byWordWrapping
      self.content = .label(label)
    }
    super.init(frame: .zero)
    addSubview(self.content.view)
    addSubview(bottomBorder)
    addSubview(trailingBorder)
  }

  required init?(coder: NSCoder) {
    nil
  }

  /// Attachments (citations, inline math) and links need a text view to
  /// render and respond to taps; everything else uses a lightweight label.
  private static func needsTextView(_ content: NSAttributedString) -> Bool {
    let fullRange = NSRange(location: 0, length: content.length)
    var needsTextView = false
    content.enumerateAttributes(in: fullRange) { attributes, _, stop in
      if attributes[.attachment] != nil || attributes[.link] != nil {
        needsTextView = true
        stop.pointee = true
      }
    }
    return needsTextView
  }

  func canDisplay(_ content: NSAttributedString) -> Bool {
    switch self.content {
    case .label: return !Self.needsTextView(content)
    case .paragraph: return Self.needsTextView(content)
    }
  }

  func update(content attributedString: NSAttributedString, accessibilityPosition: String, context: BlockContext) {
    switch content {
    case .label(let label):
      if label.attributedText != attributedString {
        label.attributedText = attributedString
        invalidateMeasurements()
      }
      label.accessibilityValue = accessibilityPosition
    case .paragraph(let paragraph):
      let contents = NSMutableAttributedString(attributedString: attributedString)
      if paragraph.paragraphContents != contents {
        let animatedByWord = window != nil && context.config.shouldAnimateText
        paragraph.setParagraphContents(contents, animatedByWord: animatedByWord)
        invalidateMeasurements()
      }
      paragraph.setTextContextMenu(context.config.resolvedTextContextMenu)
      paragraph.setMarkdownController(context.controller)
      paragraph.accessibilityValue = accessibilityPosition
    }
  }

  func configureChrome(
    isHeader: Bool,
    showsBottomBorder: Bool,
    showsTrailingBorder: Bool,
    style: MarkdownRenderConfig.MarkdownTableTextStyle
  ) {
    backgroundColor = isHeader ? style.headerBackgroundColor : nil
    bottomBorder.backgroundColor = style.borderColor
    trailingBorder.backgroundColor = style.borderColor
    bottomBorder.isHidden = !showsBottomBorder
    trailingBorder.isHidden = !showsTrailingBorder
  }

  func fadeIn() {
    content.view.alpha = 0
    UIView.animate(withDuration: ParagraphUIView.animationDuration) {
      self.content.view.alpha = 1
    }
  }

  /// The width the cell needs to show its text on as few lines as possible.
  var naturalWidth: CGFloat {
    if let cachedNaturalWidth {
      return cachedNaturalWidth
    }
    let textWidth = textSize(forWidth: Self.unconstrainedWidth).width
    let width = textWidth + Self.padding * 2 + Self.trailingSpace
    cachedNaturalWidth = width
    return width
  }

  func height(forWidth width: CGFloat) -> CGFloat {
    if let cachedHeight, cachedHeight.width == width {
      return cachedHeight.height
    }
    let height = textSize(forWidth: textWidth(forCellWidth: width)).height + Self.padding * 2
    cachedHeight = (width, height)
    return height
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    let textWidth = textWidth(forCellWidth: bounds.width)
    let textHeight = textSize(forWidth: textWidth).height
    content.view.frame = CGRect(x: Self.padding, y: Self.padding, width: textWidth, height: textHeight)
    let lineWidth: CGFloat = 1
    bottomBorder.frame = CGRect(x: 0, y: bounds.height - lineWidth, width: bounds.width, height: lineWidth)
    trailingBorder.frame = CGRect(x: bounds.width - lineWidth, y: 0, width: lineWidth, height: bounds.height)
  }

  private func textWidth(forCellWidth width: CGFloat) -> CGFloat {
    max(0, width - Self.padding * 2 - Self.trailingSpace)
  }

  private func textSize(forWidth width: CGFloat) -> CGSize {
    let fitted = content.view.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
    return CGSize(width: fitted.width.rounded(.up), height: fitted.height.rounded(.up))
  }

  private func invalidateMeasurements() {
    cachedNaturalWidth = nil
    cachedHeight = nil
    setNeedsLayout()
  }

  /// Called when the cell's text view adopts a larger laid-out height.
  func invalidateMarkdownLayout() {
    invalidateMeasurements()
  }
}

// MARK: - Action button

/// A 32-point table action with a template icon, optionally swapping to a
/// filled icon with a brief bounce when tapped.
private final class TableActionButton: UIControl {

  private let imageView = UIImageView()
  private let pressedImageView = UIImageView()
  private var feedbackTask: Task<Void, Never>?

  init(imageName: String, pressedImageName: String?) {
    super.init(frame: .zero)
    isAccessibilityElement = true
    accessibilityTraits = .button
    for (view, name) in [(imageView, imageName), (pressedImageView, pressedImageName)] {
      view.image = name.flatMap { UIImage(named: $0, in: .module, compatibleWith: nil)?.withRenderingMode(.alwaysTemplate) }
      view.contentMode = .center
      view.isUserInteractionEnabled = false
      addSubview(view)
    }
    pressedImageView.alpha = 0
  }

  required init?(coder: NSCoder) {
    nil
  }

  deinit {
    feedbackTask?.cancel()
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    imageView.frame = bounds
    pressedImageView.frame = bounds
  }

  func playPressFeedback() {
    guard pressedImageView.image != nil else { return }
    feedbackTask?.cancel()
    UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseInOut) {
      self.imageView.alpha = 0
      self.pressedImageView.alpha = 1
      self.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
    }
    feedbackTask = Task { [weak self] in
      try? await Task.sleep(ms: 200)
      guard !Task.isCancelled, let self else { return }
      UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseInOut) {
        self.imageView.alpha = 1
        self.pressedImageView.alpha = 0
        self.transform = .identity
      }
    }
  }
}
