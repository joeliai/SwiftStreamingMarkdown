//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import SwiftStreamingMarkdown
import UIKit

/// A completely custom `MarkdownRenderConfig` that demonstrates plugging in a
/// different type family (Google Roboto) and a vivid teal-on-deep-purple
/// color palette. Compare side-by-side against `MarkdownRenderConfig.default`
/// to see how every text style and color is configurable.
enum RobotoTheme {

  // MARK: - Colors

  private static func color(named name: String) -> UIColor {
    UIColor(named: name) ?? .label
  }

  private static let pageForeground = color(named: "RobotoTheme/PageForeground")
  private static let mutedForeground = color(named: "RobotoTheme/MutedForeground")
  private static let accent = color(named: "RobotoTheme/Accent")
  private static let accentSoft = color(named: "RobotoTheme/AccentSoft")
  private static let boldEmphasis = color(named: "RobotoTheme/BoldEmphasis")
  private static let codeForeground = color(named: "RobotoTheme/CodeForeground")
  private static let codeBackground = color(named: "RobotoTheme/CodeBackground")
  private static let codeUnderline = color(named: "RobotoTheme/CodeUnderline")
  private static let tableHeaderBackground = color(named: "RobotoTheme/TableHeaderBackground")
  private static let tableBorder = color(named: "RobotoTheme/TableBorder")

  /// Background applied around the rendered content to make the Roboto theme
  /// pop visually. Exposed so `DemonstrationViewController` can paint the
  /// scroll view.
  static let pageBackground = color(named: "RobotoTheme/PageBackground")

  // MARK: - Fonts

  private static func roboto(_ size: CGFloat, weight: String = "Regular") -> MDFont {
    MDFont(name: "Roboto-\(weight)", size: size)
      ?? .systemFont(ofSize: size, weight: weight == "Bold" ? .bold : (weight == "Medium" ? .medium : .regular))
  }

  private static func robotoItalic(_ size: CGFloat, bold: Bool = false) -> MDFont {
    let name = bold ? "Roboto-BoldItalic" : "Roboto-Italic"
    return MDFont(name: name, size: size) ?? .italicSystemFont(ofSize: size)
  }

  private static func textFonts(size: CGFloat, lineHeight: CGFloat? = nil, letterSpacing: CGFloat? = nil) -> TextFonts {
    TextFonts(
      normal: roboto(size, weight: "Regular"),
      italic: robotoItalic(size),
      bold: roboto(size, weight: "Bold"),
      boldItalic: robotoItalic(size, bold: true),
      preferredLetterSpacing: letterSpacing,
      preferredLineHeight: lineHeight
    )
  }

  private static func headingFonts(size: CGFloat, letterSpacing: CGFloat) -> TextFonts {
    TextFonts(
      normal: roboto(size, weight: "Medium"),
      italic: robotoItalic(size),
      bold: roboto(size, weight: "Bold"),
      boldItalic: robotoItalic(size, bold: true),
      preferredLetterSpacing: letterSpacing,
      preferredLineHeight: size * 1.2
    )
  }

  // MARK: - Config

  static let renderConfig: MarkdownRenderConfig = MarkdownRenderConfig(
    shouldAnimateText: false,
    blockQuoteStyle: .init(
      textFonts: textFonts(size: 16, lineHeight: 24),
      textColor: mutedForeground
    ),
    headingStyle: .init(
      h1Font: headingFonts(size: 32, letterSpacing: -0.5),
      h2Font: headingFonts(size: 26, letterSpacing: -0.25),
      h3Font: headingFonts(size: 22, letterSpacing: 0),
      h4Font: headingFonts(size: 19, letterSpacing: 0),
      h5Font: headingFonts(size: 17, letterSpacing: 0.5),
      h6Font: headingFonts(size: 15, letterSpacing: 0.75),
      textColor: accent
    ),
    orderedListStyle: .init(
      textFonts: textFonts(size: 16, lineHeight: 24),
      textColor: pageForeground
    ),
    paragraphStyle: .init(
      textFonts: textFonts(size: 16, lineHeight: 24, letterSpacing: 0.15),
      textColor: pageForeground
    ),
    tableStyle: .init(
      textFonts: textFonts(size: 14, lineHeight: 20),
      headerTextColor: accent,
      regularTextColor: pageForeground,
      headerBackgroundColor: tableHeaderBackground,
      borderColor: tableBorder,
      actionButtonColor: accent
    ),
    inlineStyle: .init(
      boldTextColor: boldEmphasis,
      linkTextFont: roboto(16, weight: "Medium"),
      linkTextColor: accent,
      codeTextFont: MDFont.monospacedSystemFont(ofSize: 15, weight: .regular),
      codeTextColor: codeForeground,
      codeBackgroundColor: codeBackground,
      codeUnderlineColor: codeUnderline
    ),
    textContextMenu: nil,
    citationConfig: .init(
      isEnabled: true,
      font: roboto(12, weight: "Medium"),
      textColor: pageForeground,
      backgroundColor: accentSoft
    ),
    codeBlockConfig: .init(
      theme: .atomOne,
      backgroundColor: .dynamic(
        light: UIColor(red: 0.980, green: 0.980, blue: 0.980, alpha: 1),
        dark: UIColor(red: 0.157, green: 0.173, blue: 0.204, alpha: 1)
      )
    ),
    textSelectionConfig: .init(backgroundColor: pageBackground),
    thematicBreakColor: tableBorder
  )
}
