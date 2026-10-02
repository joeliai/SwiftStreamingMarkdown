//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import UIKit

/// Loads the image for a resolved block-image source off the main thread.
enum ImageLoader {

  private static let remoteImageCache = NSCache<NSURL, UIImage>()

  /// Loads and decodes the image for `source`, or returns `nil` when it cannot
  /// be loaded. `controller` provides the listener fallback for bundled
  /// resources missing from the main bundle.
  static func image(for source: ImageData.Source, controller: MarkdownController?) async -> UIImage? {
    let image: UIImage?
    switch source {
    case .remote(let url):
      image = await remoteImage(at: url)
    case .assetCatalog(let name):
      image = UIImage(named: name)
    case .bundledResource(let fileName, let ext):
      image = await fileName.bundledResourceImage(withExtension: ext, controller: controller)
    }
    guard let image else { return nil }
    return await image.byPreparingForDisplay() ?? image
  }

  private static func remoteImage(at url: URL) async -> UIImage? {
    if let cached = remoteImageCache.object(forKey: url as NSURL) {
      return cached
    }
    guard let (data, response) = try? await URLSession.shared.data(from: url),
          let httpResponse = response as? HTTPURLResponse,
          (200..<300).contains(httpResponse.statusCode),
          let image = UIImage(data: data) else {
      return nil
    }
    remoteImageCache.setObject(image, forKey: url as NSURL)
    return image
  }
}
