//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import UIKit
import UniformTypeIdentifiers

final class InlineCitationAttachment: NSTextAttachment {
  /// The decoded citation data - available immediately without JSON parsing
  private(set) var citationData: InlineAttachmentData?

  /// Styling resolved from the active `CitationConfig`. Exposed so the live
  /// label provider can mirror the same look as the precomputed preview image.
  let font: MDFont
  let textColor: MDColor
  let backgroundColor: MDColor

  // MARK: - Precomputed preview images

  private var lightPreviewImage: MDImage?
  private var darkPreviewImage: MDImage?
  private var assignedImage: MDImage?

  // MARK: - Shared Layout

  static let textInsets = MDEdgeInsets(top: 2, left: 4, bottom: 2, right: 4)
  static let cornerRadius: CGFloat = 6

  override var image: UIImage? {
    get {
      if let assignedImage { return assignedImage }
      let app = AppAppearance.$current.read({ $0 })
      switch app {
      case .dark: return darkPreviewImage
      case .light: return lightPreviewImage
      }
    }
    set { assignedImage = newValue }
  }

  /// Called during markdown parsing (background queue). Rasterizes both
  /// light/dark previews here so the getter never does work on the main thread.
  init(payload: Data, citationConfig: MarkdownRenderConfig.CitationConfig) {
    let decoded = try? JSONDecoder().decode(InlineAttachmentData.self, from: payload)
    let citationData = (decoded?.type == .citation) ? decoded : nil
    self.citationData = citationData

    self.font = citationConfig.font
    self.textColor = citationConfig.textColor
    self.backgroundColor = citationConfig.backgroundColor

    if let title = citationData?.title {
      self.lightPreviewImage = Self.renderCitationImage(
        title: title, font: self.font,
        textColor: self.textColor, backgroundColor: self.backgroundColor,
        appearance: .light
      )
      self.darkPreviewImage = Self.renderCitationImage(
        title: title, font: self.font,
        textColor: self.textColor, backgroundColor: self.backgroundColor,
        appearance: .dark
      )
    } else {
      self.lightPreviewImage = nil
      self.darkPreviewImage = nil
    }

    super.init(data: payload, ofType: UTType.url.identifier)
  }

  /// Create citation attachment directly from data struct
  convenience init?(citationData: InlineAttachmentData, citationConfig: MarkdownRenderConfig.CitationConfig) {
    guard citationData.type == .citation,
          let payload = try? JSONEncoder().encode(citationData) else {
      return nil
    }
    self.init(payload: payload, citationConfig: citationConfig)
  }

  required init?(coder: NSCoder) {
    return nil
  }

  // MARK: - Preview Image Rendering

  private static func renderCitationImage(
    title: String, font: MDFont,
    textColor: MDColor, backgroundColor: MDColor,
    appearance: AppAppearance
  ) -> MDImage {
    // Resolve colors for the target appearance
    let traitCollection = UITraitCollection(userInterfaceStyle: appearance.platformType)
    let resolvedTextColor = textColor.resolvedColor(with: traitCollection)
    let resolvedBackgroundColor = backgroundColor.resolvedColor(with: traitCollection)

    let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: resolvedTextColor]
    let textSize = (title as NSString).size(withAttributes: attributes)
    let totalSize = CGSize(
      width: ceil(textSize.width) + textInsets.left + textInsets.right,
      height: ceil(textSize.height) + textInsets.top + textInsets.bottom
    )

    // Render the citation pill image
    let renderer = UIGraphicsImageRenderer(size: totalSize)
    return renderer.image { _ in
      let rect = CGRect(origin: .zero, size: totalSize)
      let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
      resolvedBackgroundColor.setFill()
      path.fill()

      let textRect = CGRect(x: textInsets.left, y: textInsets.top,
                            width: ceil(textSize.width), height: ceil(textSize.height))
      (title as NSString).draw(in: textRect, withAttributes: attributes)
    }
  }
}
