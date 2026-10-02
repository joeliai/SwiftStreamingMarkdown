//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import UIKit

class ParagraphViewCache {
  @WithLock
  private var cachedViews: [ParagraphUIView] = []
  private let maxCacheSize = 50

  private init() {}

  static let shared: ParagraphViewCache = .init()

  func createOrReuseView() -> ParagraphUIView {
    if let availableView = findAvailableCachedView() {
      return availableView
    }
    let newView = ParagraphUIView()
    if $cachedViews.read(closure: { $0.count }) < maxCacheSize {
      $cachedViews.mutate { $0.append(newView) }
    }
    return newView
  }

  func clearCache() {
    $cachedViews.mutate { $0.removeAll() }
  }

  private func findAvailableCachedView() -> ParagraphUIView? {
    $cachedViews.read(closure: { cachedView in
      cachedView.first { view in
        view.superview == nil && view.window == nil
      }
    })
  }
}
