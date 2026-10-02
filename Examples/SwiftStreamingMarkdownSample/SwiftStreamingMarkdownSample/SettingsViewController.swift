//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import UIKit

/// Sample-wide preferences: streamed vs. static rendering, the Markdown theme,
/// and the appearance override.
final class SettingsViewController: UITableViewController {

  private enum Row: Int, CaseIterable {
    case streamed
    case markdownTheme
    case appearance
  }

  private static let cellIdentifier = "SettingsCell"
  private let settings = SampleSettings.shared

  init() {
    super.init(style: .insetGrouped)
    title = "Settings"
  }

  required init?(coder: NSCoder) {
    nil
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    navigationItem.largeTitleDisplayMode = .never
    tableView.register(UITableViewCell.self, forCellReuseIdentifier: Self.cellIdentifier)
    tableView.allowsSelection = false
  }

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    Row.allCases.count
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: Self.cellIdentifier, for: indexPath)
    var content = cell.defaultContentConfiguration()
    switch Row(rawValue: indexPath.row) {
    case .streamed:
      content.text = "Streamed"
      let toggle = UISwitch()
      toggle.isOn = settings.preferStreamedMarkdown
      toggle.addAction(UIAction { [weak self] action in
        self?.settings.preferStreamedMarkdown = (action.sender as? UISwitch)?.isOn ?? true
      }, for: .valueChanged)
      cell.accessoryView = toggle
    case .markdownTheme:
      content.text = "Markdown Theme"
      cell.accessoryView = menuButton(
        options: SampleMarkdownTheme.allCases.map { ($0.displayName, $0 == settings.markdownTheme) }
      ) { [weak self] index in
        self?.settings.markdownTheme = SampleMarkdownTheme.allCases[index]
      }
    case .appearance:
      content.text = "Appearance"
      cell.accessoryView = menuButton(
        options: AppearanceMode.allCases.map { ($0.displayName, $0 == settings.appearanceMode) }
      ) { [weak self] index in
        self?.settings.appearanceMode = AppearanceMode.allCases[index]
      }
    case nil:
      break
    }
    cell.contentConfiguration = content
    return cell
  }

  /// A pop-up button listing `options` that reports the chosen index.
  private func menuButton(options: [(title: String, isSelected: Bool)], onSelect: @escaping (Int) -> Void) -> UIButton {
    let actions = options.enumerated().map { index, option in
      UIAction(title: option.title, state: option.isSelected ? .on : .off) { _ in onSelect(index) }
    }
    var configuration = UIButton.Configuration.plain()
    configuration.contentInsets = .zero
    let button = UIButton(configuration: configuration)
    button.menu = UIMenu(children: actions)
    button.showsMenuAsPrimaryAction = true
    button.changesSelectionAsPrimaryAction = true
    button.sizeToFit()
    return button
  }
}
