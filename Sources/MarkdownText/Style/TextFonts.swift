//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//
import UIKit

/// A bundle of font variants (normal/italic/bold/boldItalic) plus optional
/// preferred letter and line spacing values, used by `MarkdownRenderConfig`
/// to style a run of text.
public struct TextFonts: Hashable, Sendable {
  /// Regular variant. Always required.
  public let normal: MDFont
  /// Italic variant, or `nil` to fall back to `normal` for emphasis.
  public let italic: MDFont?
  /// Bold variant, or `nil` to fall back to `normal` for strong runs.
  public let bold: MDFont?
  /// Bold-italic variant, or `nil` to fall back to `bold` then `italic`.
  public let boldItalic: MDFont?
  /// Optional kerning override applied via `NSAttributedString.Key.kern`.
  public let preferredLetterSpacing: CGFloat?
  /// Optional preferred line height in points. When greater than the font's
  /// natural line height, the renderer adds the difference as line spacing.
  public let preferredLineHeight: CGFloat?

  /// Create a font set with explicit variants and optional spacing overrides.
  public init(normal: MDFont, italic: MDFont?, bold: MDFont?, boldItalic: MDFont?, preferredLetterSpacing: CGFloat?, preferredLineHeight: CGFloat?) {
    self.normal = normal
    self.italic = italic
    self.bold = bold
    self.boldItalic = boldItalic
    self.preferredLetterSpacing = preferredLetterSpacing
    self.preferredLineHeight = preferredLineHeight
  }
}

extension TextFonts {

  func italicize(font: MDFont) -> MDFont? {
    if font == bold || font == boldItalic {
      return self.boldItalic
    }
    return self.italic
  }

  func bold(font: MDFont) -> MDFont? {
    if font == italic || font == boldItalic {
      return self.boldItalic
    }
    return self.bold
  }
}

extension TextFonts {

  /// The variant for the requested traits, falling back to `normal` when the
  /// variant is not provided.
  func font(bold: Bool = false, italic: Bool = false) -> MDFont {
    let variant: MDFont?
    if bold && italic {
      variant = boldItalic
    } else if bold {
      variant = self.bold
    } else if italic {
      variant = self.italic
    } else {
      variant = normal
    }
    return variant ?? normal
  }

  /// The spacing to add between lines so they reach `preferredLineHeight`, or
  /// `nil` when the font's natural line height is already tall enough.
  var extraLineSpacing: CGFloat? {
    guard let preferredLineHeight, preferredLineHeight > normal.lineHeight else {
      return nil
    }
    return preferredLineHeight - normal.lineHeight
  }

  /// Text attributes that apply the requested font variant and the preferred
  /// letter spacing as kerning. When `appliesLineHeight` is `true`, the
  /// preferred line height is applied as extra spacing between lines.
  func textAttributes(
    color: UIColor,
    bold: Bool = false,
    italic: Bool = false,
    appliesLineHeight: Bool = true
  ) -> [NSAttributedString.Key: Any] {
    var attributes: [NSAttributedString.Key: Any] = [
      .font: font(bold: bold, italic: italic),
      .foregroundColor: color
    ]
    if let preferredLetterSpacing {
      attributes[.kern] = preferredLetterSpacing
    }
    if appliesLineHeight, let extraLineSpacing {
      let paragraphStyle = NSMutableParagraphStyle()
      paragraphStyle.lineSpacing = extraLineSpacing
      attributes[.paragraphStyle] = paragraphStyle
    }
    return attributes
  }
}
