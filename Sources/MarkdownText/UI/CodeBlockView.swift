//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import HighlightSwift
import UIKit

/// Renders a fenced code block: a chrome header with the language and a copy
/// control above horizontally scrollable, syntax-highlighted code.
final class CodeBlockView: UIView, MarkdownBlockView {

  private static let cornerRadius: CGFloat = 20
  private static let headerInsets = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
  private static let codeInset: CGFloat = 16

  private let headerView = UIView()
  private let languageLabel = UILabel()
  private let copyButton = CopyButton()
  private let codeBackgroundView = UIView()
  private let scrollView = UIScrollView()
  private let codeLabel = UILabel()

  private let highlightManager = HighlightTaskManager()
  private var codeBlockConfig: CodeBlockConfig = .default
  private var language = ""
  private var code = ""
  private var highlightedCode: AttributedString?
  private var isCopied = false
  private var copyResetTask: Task<Void, Never>?
  private var cachedCodeSize: CGSize?

  init() {
    super.init(frame: .zero)
    headerView.layer.cornerRadius = Self.cornerRadius
    headerView.layer.cornerCurve = .continuous
    headerView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
    addSubview(headerView)

    languageLabel.numberOfLines = 1
    headerView.addSubview(languageLabel)

    copyButton.addTarget(self, action: #selector(copyCode), for: .touchUpInside)
    headerView.addSubview(copyButton)

    codeBackgroundView.layer.cornerRadius = Self.cornerRadius
    codeBackgroundView.layer.cornerCurve = .continuous
    codeBackgroundView.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
    addSubview(codeBackgroundView)

    scrollView.showsVerticalScrollIndicator = false
    scrollView.alwaysBounceVertical = false
    codeBackgroundView.addSubview(scrollView)

    codeLabel.numberOfLines = 0
    codeLabel.lineBreakMode = .byClipping
    scrollView.addSubview(codeLabel)
  }

  required init?(coder: NSCoder) {
    nil
  }

  deinit {
    copyResetTask?.cancel()
  }

  // MARK: - MarkdownBlockView

  func update(with renderable: MarkdownRenderable, context: BlockContext) {
    guard case .codeBlock(_, let languageTag, let code) = renderable else { return }
    let language = languageTag ?? ""
    let config = context.config.codeBlockConfig
    let needsHighlight = code != self.code || config != codeBlockConfig
    let isFirstUpdate = self.code.isEmpty && highlightedCode == nil

    self.language = language
    self.code = code
    self.codeBlockConfig = config

    let backgroundColor = config.backgroundColor ?? .clear
    headerView.backgroundColor = backgroundColor
    codeBackgroundView.backgroundColor = backgroundColor
    applyChromeText()
    if needsHighlight || isFirstUpdate {
      applyCodeText()
      highlight()
    }
  }

  func height(forWidth width: CGFloat) -> CGFloat {
    headerHeight + Self.codeInset * 2 + codeSize.height
  }

  override func sizeThatFits(_ size: CGSize) -> CGSize {
    CGSize(width: size.width, height: height(forWidth: size.width))
  }

  // MARK: - Layout

  private var headerHeight: CGFloat {
    let insets = Self.headerInsets
    let contentHeight = max(languageLabel.intrinsicContentSize.height, copyButton.intrinsicContentSize.height)
    return insets.top + contentHeight + insets.bottom
  }

  private var codeSize: CGSize {
    if let cachedCodeSize {
      return cachedCodeSize
    }
    let fitted = codeLabel.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude))
    let size = CGSize(width: fitted.width.rounded(.up), height: fitted.height.rounded(.up))
    cachedCodeSize = size
    return size
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    let width = bounds.width
    let insets = Self.headerInsets
    let headerHeight = self.headerHeight
    headerView.frame = CGRect(x: 0, y: 0, width: width, height: headerHeight)

    let copySize = copyButton.intrinsicContentSize
    copyButton.frame = CGRect(
      x: width - insets.right - copySize.width,
      y: insets.top,
      width: copySize.width,
      height: copySize.height
    )
    let languageWidth = max(0, copyButton.frame.minX - insets.left - 8)
    languageLabel.frame = CGRect(
      x: insets.left,
      y: insets.top,
      width: min(languageLabel.intrinsicContentSize.width, languageWidth),
      height: languageLabel.intrinsicContentSize.height
    )

    let codeSize = self.codeSize
    codeBackgroundView.frame = CGRect(x: 0, y: headerHeight, width: width, height: codeSize.height + Self.codeInset * 2)
    scrollView.frame = CGRect(
      x: Self.codeInset,
      y: Self.codeInset,
      width: max(0, width - Self.codeInset * 2),
      height: codeSize.height
    )
    codeLabel.frame = CGRect(origin: .zero, size: codeSize)
    scrollView.contentSize = codeSize
  }

  override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    if traitCollection.userInterfaceStyle != previousTraitCollection?.userInterfaceStyle, !code.isEmpty {
      highlight()
    }
  }

  // MARK: - Content

  private var chromeColor: UIColor {
    codeBlockConfig.foregroundColor ?? UIColor.Static.Stone.Stone350
  }

  private func applyChromeText() {
    let attributes = codeBlockConfig.chromeTextFonts.textAttributes(color: chromeColor, appliesLineHeight: false)
    languageLabel.attributedText = NSAttributedString(string: language, attributes: attributes)
    copyButton.configure(
      title: isCopied ? String.codeCopiedLabel : String.codeCopyLabel,
      attributes: attributes,
      tintColor: chromeColor
    )
    headerView.setNeedsLayout()
  }

  private func applyCodeText() {
    let fonts = codeBlockConfig.codeTextFonts
    let text: NSAttributedString
    if let highlightedCode, let converted = try? NSAttributedString(highlightedCode, including: \.uiKit) {
      // Keep the highlighter's colors, but use the configured fonts.
      let highlighted = NSMutableAttributedString(attributedString: converted)
      var attributes = fonts.textAttributes(color: .label)
      attributes[.foregroundColor] = nil
      highlighted.addAttributes(attributes, range: NSRange(location: 0, length: highlighted.length))
      text = highlighted
    } else if #available(iOS 16.1, *) {
      text = NSAttributedString(string: code.trimmingTrailingNewlines, attributes: fonts.textAttributes(color: .label))
    } else {
      // Syntax highlighting needs iOS 16.1.
      let color = UIColor.Theme.Component.CodeBlock.Foreground.FunctionParameter
      text = NSAttributedString(string: code.trimmingTrailingNewlines, attributes: fonts.textAttributes(color: color))
    }

    let previousSize = cachedCodeSize
    codeLabel.attributedText = text
    cachedCodeSize = nil
    if previousSize != codeSize {
      setNeedsMarkdownLayout()
    }
    setNeedsLayout()
  }

  private func highlight() {
    guard #available(iOS 16.1, *) else { return }
    let colors = codeBlockConfig.theme.highlightColors(for: traitCollection.userInterfaceStyle)
    let code = self.code
    let highlightManager = self.highlightManager
    Task { [weak self] in
      await highlightManager.enqueueCode(code, colors: colors) { attributedString in
        guard let self else { return }
        self.highlightedCode = attributedString
        self.applyCodeText()
      }
    }
  }

  @objc private func copyCode() {
    UIPasteboard.general.string = code
    setCopied(true)
    copyResetTask?.cancel()
    copyResetTask = Task { [weak self] in
      try? await Task.sleep(seconds: 3)
      guard !Task.isCancelled else { return }
      self?.setCopied(false)
    }
  }

  private func setCopied(_ copied: Bool) {
    guard isCopied != copied else { return }
    isCopied = copied
    applyChromeText()
    setNeedsLayout()
  }
}

// MARK: - Copy button

/// The copy icon followed by the "Copy"/"Copied" title, with the icon's bottom
/// resting on the title's baseline.
private final class CopyButton: UIControl {

  private static let spacing: CGFloat = 6

  private let iconView = UIImageView(image: UIImage(named: "copyIcon14", in: .module, compatibleWith: nil)?.withRenderingMode(.alwaysTemplate))
  private let titleLabel = UILabel()
  private var titleFont: UIFont?

  override init(frame: CGRect) {
    super.init(frame: frame)
    isAccessibilityElement = true
    accessibilityTraits = .button
    iconView.isUserInteractionEnabled = false
    titleLabel.isUserInteractionEnabled = false
    addSubview(iconView)
    addSubview(titleLabel)
  }

  required init?(coder: NSCoder) {
    nil
  }

  func configure(title: String, attributes: [NSAttributedString.Key: Any], tintColor: UIColor) {
    titleLabel.attributedText = NSAttributedString(string: title, attributes: attributes)
    titleFont = attributes[.font] as? UIFont
    iconView.tintColor = tintColor
    accessibilityLabel = title
    invalidateIntrinsicContentSize()
    setNeedsLayout()
  }

  override var intrinsicContentSize: CGSize {
    let titleSize = titleLabel.intrinsicContentSize
    let iconSize = iconView.intrinsicContentSize
    return CGSize(width: iconSize.width + Self.spacing + titleSize.width, height: max(titleSize.height, iconSize.height))
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    let titleSize = titleLabel.intrinsicContentSize
    let iconSize = iconView.intrinsicContentSize
    let baseline = (titleFont?.ascender ?? titleSize.height).rounded(.up)
    iconView.frame = CGRect(x: 0, y: max(0, baseline - iconSize.height), width: iconSize.width, height: iconSize.height)
    titleLabel.frame = CGRect(x: iconSize.width + Self.spacing, y: 0, width: titleSize.width, height: titleSize.height)
  }

  override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
    // Keep the small control comfortably tappable.
    bounds.insetBy(dx: -12, dy: -12).contains(point)
  }
}

private extension String {
  var trimmingTrailingNewlines: String {
    var result = self
    while result.last?.isNewline == true {
      result.removeLast()
    }
    return result
  }
}
