//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import UIKit

/// A sheet that presents the full document as selectable, uneditable text so
/// the user can select more than the tapped block. Presented by `DocumentView`
/// when the built-in "Select more text" edit-menu action is invoked.
final class TextSelectionViewController: UIViewController {

  private let text: String
  private let config: MarkdownRenderConfig

  private let titleLabel = UILabel()
  private let closeButton = UIButton(type: .system)
  private let separator = UIView()
  let textView = UITextView()

  init(text: String, config: MarkdownRenderConfig) {
    self.text = text
    self.config = config
    super.init(nibName: nil, bundle: nil)
    modalPresentationStyle = .pageSheet
  }

  required init?(coder: NSCoder) {
    nil
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = config.textSelectionConfig.backgroundColor ?? UIColor.Theme.Background.Page.Chat.Flat

    let headingStyle = config.headingStyle
    titleLabel.text = String.selectMoreTextLabel
    titleLabel.font = headingStyle.h3Font.bold ?? headingStyle.h3Font.normal
    titleLabel.textColor = headingStyle.textColor
    titleLabel.textAlignment = .center
    titleLabel.accessibilityTraits = .header

    closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
    closeButton.tintColor = headingStyle.textColor
    closeButton.accessibilityLabel = String.textSelectionCloseLabel
    closeButton.addTarget(self, action: #selector(close), for: .touchUpInside)

    separator.backgroundColor = config.thematicBreakColor

    textView.isEditable = false
    textView.isSelectable = true
    textView.backgroundColor = .clear
    textView.showsVerticalScrollIndicator = false
    textView.tintColor = UIColor.Theme.Accent.Accent600
    textView.attributedText = Self.selectionAttributedString(for: text)

    let header = UIView()
    for subview in [titleLabel, closeButton, separator] {
      subview.translatesAutoresizingMaskIntoConstraints = false
      header.addSubview(subview)
    }
    for subview in [header, textView] {
      subview.translatesAutoresizingMaskIntoConstraints = false
      view.addSubview(subview)
    }
    NSLayoutConstraint.activate([
      header.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
      header.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      header.trailingAnchor.constraint(equalTo: view.trailingAnchor),

      titleLabel.topAnchor.constraint(equalTo: header.topAnchor, constant: 18),
      titleLabel.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: -18),
      titleLabel.centerXAnchor.constraint(equalTo: header.centerXAnchor),
      titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: header.leadingAnchor, constant: 24),
      titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: closeButton.leadingAnchor, constant: -8),

      closeButton.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -24),
      closeButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),

      separator.leadingAnchor.constraint(equalTo: header.leadingAnchor),
      separator.trailingAnchor.constraint(equalTo: header.trailingAnchor),
      separator.bottomAnchor.constraint(equalTo: header.bottomAnchor),
      separator.heightAnchor.constraint(equalToConstant: 1),

      textView.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 14),
      textView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 18),
      textView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18),
      textView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
    ])
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    // Preselect the first paragraph so the user can immediately extend the
    // selection.
    let range = Self.firstParagraphRange(in: text)
    guard let start = textView.position(from: textView.beginningOfDocument, offset: range.location),
          let end = textView.position(from: start, offset: range.length) else {
      return
    }
    textView.selectedTextRange = textView.textRange(from: start, to: end)
    textView.becomeFirstResponder()
  }

  @objc private func close() {
    dismiss(animated: true)
  }

  private static func selectionAttributedString(for text: String) -> NSAttributedString {
    let fonts = Typography.baseTextFonts
    var attributes = fonts.textAttributes(color: UIColor.Theme.Foreground.Primary.Primary800)
    let paragraphStyle = (attributes[.paragraphStyle] as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle
      ?? NSMutableParagraphStyle()
    paragraphStyle.alignment = .left
    attributes[.paragraphStyle] = paragraphStyle
    return NSAttributedString(string: text, attributes: attributes)
  }

  /// The range of the first paragraph (up to the first newline), or the whole
  /// string when it contains no newline.
  static func firstParagraphRange(in text: String) -> NSRange {
    let nsText = text as NSString
    guard nsText.length > 0 else { return NSRange(location: 0, length: 0) }
    let newline = nsText.rangeOfCharacter(from: .newlines)
    if newline.location != NSNotFound {
      return NSRange(location: 0, length: newline.location)
    }
    return NSRange(location: 0, length: nsText.length)
  }
}
