//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import UIKit

/// The chat input bar: a growing text view (up to five lines) and a send
/// button that is enabled while the draft is not blank.
final class MessageComposerView: UIView, UITextViewDelegate {

  var onSend: ((String) -> Void)?

  private let textView = UITextView()
  private let placeholderLabel = UILabel()
  private let sendButton = UIButton(type: .custom)
  private lazy var textHeightConstraint = textView.heightAnchor.constraint(equalToConstant: lineHeight)

  private var lineHeight: CGFloat {
    (textView.font ?? .preferredFont(forTextStyle: .body)).lineHeight
  }

  override init(frame: CGRect) {
    super.init(frame: frame)
    let background = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterial))
    let field = UIView()
    field.backgroundColor = UIColor.secondaryLabel.withAlphaComponent(0.12)
    field.layer.cornerRadius = 20
    field.layer.cornerCurve = .continuous

    textView.font = .preferredFont(forTextStyle: .body)
    textView.backgroundColor = .clear
    textView.textContainerInset = .zero
    textView.textContainer.lineFragmentPadding = 0
    textView.isScrollEnabled = false
    textView.delegate = self
    textView.accessibilityLabel = "Message"

    placeholderLabel.text = "Message"
    placeholderLabel.font = textView.font
    placeholderLabel.textColor = .placeholderText
    placeholderLabel.isAccessibilityElement = false

    let symbol = UIImage(systemName: "arrow.up", withConfiguration: UIImage.SymbolConfiguration(textStyle: .headline))
    sendButton.setImage(symbol, for: .normal)
    sendButton.tintColor = .white
    sendButton.backgroundColor = .systemBlue
    sendButton.layer.cornerRadius = 19
    sendButton.accessibilityLabel = "Send message"
    sendButton.addAction(UIAction { [weak self] _ in self?.send() }, for: .touchUpInside)

    for view in [background, field, textView, placeholderLabel, sendButton] {
      view.translatesAutoresizingMaskIntoConstraints = false
    }
    addSubview(background)
    addSubview(field)
    field.addSubview(textView)
    field.addSubview(placeholderLabel)
    addSubview(sendButton)
    NSLayoutConstraint.activate([
      background.topAnchor.constraint(equalTo: topAnchor),
      background.leadingAnchor.constraint(equalTo: leadingAnchor),
      background.trailingAnchor.constraint(equalTo: trailingAnchor),
      background.bottomAnchor.constraint(equalTo: bottomAnchor),

      field.topAnchor.constraint(equalTo: topAnchor, constant: 10),
      field.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -10),
      field.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 16),
      field.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -12),

      textView.topAnchor.constraint(equalTo: field.topAnchor, constant: 10),
      textView.bottomAnchor.constraint(equalTo: field.bottomAnchor, constant: -10),
      textView.leadingAnchor.constraint(equalTo: field.leadingAnchor, constant: 14),
      textView.trailingAnchor.constraint(equalTo: field.trailingAnchor, constant: -14),
      textHeightConstraint,

      placeholderLabel.leadingAnchor.constraint(equalTo: textView.leadingAnchor),
      placeholderLabel.centerYAnchor.constraint(equalTo: textView.centerYAnchor),

      sendButton.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -16),
      sendButton.bottomAnchor.constraint(equalTo: field.bottomAnchor),
      sendButton.widthAnchor.constraint(equalToConstant: 38),
      sendButton.heightAnchor.constraint(equalToConstant: 38)
    ])
    updateState()
  }

  required init?(coder: NSCoder) {
    nil
  }

  func textViewDidChange(_ textView: UITextView) {
    updateState()
  }

  private var draft: String {
    textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func updateState() {
    placeholderLabel.isHidden = !textView.text.isEmpty
    sendButton.isEnabled = !draft.isEmpty
    sendButton.alpha = draft.isEmpty ? 0.4 : 1

    // Grow with the text up to five lines, then scroll.
    let maxHeight = lineHeight * 5
    let fittingHeight = textView.sizeThatFits(
      CGSize(width: max(textView.bounds.width, 1), height: .greatestFiniteMagnitude)
    ).height
    textView.isScrollEnabled = fittingHeight > maxHeight
    textHeightConstraint.constant = min(max(fittingHeight, lineHeight), maxHeight)
  }

  private func send() {
    let text = draft
    guard !text.isEmpty else { return }
    onSend?(text)
    textView.text = ""
    updateState()
  }
}
