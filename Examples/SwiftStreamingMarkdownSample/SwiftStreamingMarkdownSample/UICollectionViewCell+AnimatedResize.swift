//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import UIKit

extension UICollectionViewCell {
  /// Applies `changes` and resizes the cell to fit its new content, animating
  /// both, along with the cells that move to make room.
  func animateResize(_ changes: @escaping () -> Void, completion: (() -> Void)? = nil) {
    UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.85, initialSpringVelocity: 0) {
      changes()
      // Inside an animation, stack views apply changes to their arranged
      // views' visibility on their next layout, which must happen before the
      // cell is measured.
      self.contentView.layoutIfNeeded()
      // Resizing inside the animation moves the cells around this one along
      // with it.
      self.invalidateIntrinsicContentSize()
      self.enclosingCollectionView?.layoutIfNeeded()
    } completion: { _ in
      completion?()
    }
  }

  private var enclosingCollectionView: UICollectionView? {
    var ancestor = superview
    while let view = ancestor {
      if let collectionView = view as? UICollectionView {
        return collectionView
      }
      ancestor = view.superview
    }
    return nil
  }
}
