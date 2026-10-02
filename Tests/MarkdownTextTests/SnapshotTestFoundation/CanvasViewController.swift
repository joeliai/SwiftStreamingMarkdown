//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import UIKit
@testable import SwiftStreamingMarkdown

/// Hosts a view for snapshot tests: on the chat page background, inside the
/// safe area inset by `insets`, either pinned to the top or vertically centered.
/// The view is sized with `sizeThatFits(_:)` for the available width.
final class CanvasViewController: UIViewController {

  enum VerticalAlignment {
    case top
    case center
  }

  private let content: UIView
  private let insets: UIEdgeInsets
  private let verticalAlignment: VerticalAlignment

  init(content: UIView, insets: UIEdgeInsets = .zero, verticalAlignment: VerticalAlignment = .top) {
    self.content = content
    self.insets = insets
    self.verticalAlignment = verticalAlignment
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    nil
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = UIColor.Theme.Background.Page.Chat.Flat
    view.addSubview(content)
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    let area = view.bounds.inset(by: view.safeAreaInsets).inset(by: insets)
    // Laying out can reveal size changes (e.g. inline math resolving its
    // bounds), so let the content settle over a few passes.
    for _ in 0..<3 {
      let height = content.sizeThatFits(CGSize(width: area.width, height: .greatestFiniteMagnitude)).height
      let y = verticalAlignment == .top ? area.minY : area.midY - height / 2
      let frame = CGRect(x: area.minX, y: y, width: area.width, height: height)
      guard frame != content.frame else { break }
      content.frame = frame
      content.layoutIfNeeded()
    }
  }
}
