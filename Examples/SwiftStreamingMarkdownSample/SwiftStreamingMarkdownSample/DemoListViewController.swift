//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import UIKit

/// The root screen: the featured LLM chat followed by every Markdown
/// demonstration, loaded from the bundled fixtures.
final class DemoListViewController: UITableViewController {

  private enum Section: Int, CaseIterable {
    case featured
    case demonstrations

    var title: String {
      switch self {
      case .featured: return "Featured"
      case .demonstrations: return "Demonstrations"
      }
    }
  }

  private static let cellIdentifier = "DemoCell"

  private var fixtures: [Demonstration: String] = [:]
  private var isLoading = true

  init() {
    super.init(style: .insetGrouped)
    title = "Markdown Demos"
  }

  required init?(coder: NSCoder) {
    nil
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    tableView.register(UITableViewCell.self, forCellReuseIdentifier: Self.cellIdentifier)
    navigationItem.rightBarButtonItem = UIBarButtonItem(
      image: UIImage(systemName: "gearshape"),
      primaryAction: UIAction { [weak self] _ in
        self?.navigationController?.pushViewController(SettingsViewController(), animated: true)
      }
    )
    navigationItem.rightBarButtonItem?.accessibilityLabel = "Settings"
    showLoadingIndicator()

    Task { [weak self] in
      let fixtures = await Self.loadFixtures()
      guard let self else { return }
      self.fixtures = fixtures
      self.isLoading = false
      self.tableView.backgroundView = nil
      self.tableView.reloadData()
    }
  }

  private func showLoadingIndicator() {
    let spinner = UIActivityIndicatorView(style: .medium)
    spinner.startAnimating()
    let label = UILabel()
    label.text = "Loading demonstrations..."
    label.font = .preferredFont(forTextStyle: .subheadline)
    label.textColor = .secondaryLabel
    let stack = UIStackView(arrangedSubviews: [spinner, label])
    stack.axis = .vertical
    stack.spacing = 12
    stack.translatesAutoresizingMaskIntoConstraints = false
    let container = UIView()
    container.addSubview(stack)
    NSLayoutConstraint.activate([
      stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
      stack.centerYAnchor.constraint(equalTo: container.centerYAnchor)
    ])
    tableView.backgroundView = container
  }

  private static func loadFixtures() async -> [Demonstration: String] {
    var loaded: [Demonstration: String] = [:]
    for demo in Demonstration.allCases {
      let fixtureFileName = demo.fixtureFileName
      if let url = Bundle.main.url(forResource: fixtureFileName, withExtension: "md"),
         let data = try? Data(contentsOf: url),
         let text = String(data: data, encoding: .utf8) {
        loaded[demo] = text
      } else {
        loaded[demo] = "# Unable to load \(demo.rawValue)\n\nExpected fixture: \(fixtureFileName).md"
      }
    }
    return loaded
  }

  // MARK: - UITableViewDataSource

  override func numberOfSections(in tableView: UITableView) -> Int {
    isLoading ? 0 : Section.allCases.count
  }

  override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    Section(rawValue: section)?.title
  }

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    switch Section(rawValue: section) {
    case .featured: return 1
    case .demonstrations: return Demonstration.allCases.count
    case nil: return 0
    }
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: Self.cellIdentifier, for: indexPath)
    var content = UIListContentConfiguration.subtitleCell()
    content.textProperties.font = .preferredFont(forTextStyle: .headline)
    content.secondaryTextProperties.font = .preferredFont(forTextStyle: .subheadline)
    content.secondaryTextProperties.color = .secondaryLabel
    content.textToSecondaryTextVerticalPadding = 4
    switch Section(rawValue: indexPath.section) {
    case .featured:
      content.text = "LLM Chat"
      content.secondaryText = "Interactive chat with rich mock Markdown responses in a UICollectionView"
    case .demonstrations:
      let demo = Demonstration.allCases[indexPath.row]
      content.text = demo.rawValue
      content.secondaryText = demo.subtitle
    case nil:
      break
    }
    cell.contentConfiguration = content
    cell.accessoryType = .disclosureIndicator
    return cell
  }

  // MARK: - UITableViewDelegate

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    let destination: UIViewController
    switch Section(rawValue: indexPath.section) {
    case .featured:
      destination = LLMChatViewController()
    case .demonstrations:
      let demo = Demonstration.allCases[indexPath.row]
      destination = DemonstrationViewController(
        demonstration: demo,
        markdownText: fixtures[demo] ?? "# Unable to load \(demo.rawValue)"
      )
    case nil:
      return
    }
    navigationController?.pushViewController(destination, animated: true)
  }
}
