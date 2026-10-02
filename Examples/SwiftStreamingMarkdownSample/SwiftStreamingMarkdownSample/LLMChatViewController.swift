//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import Combine
import SwiftStreamingMarkdown
import UIKit

/// A chat transcript in a `UICollectionView` with self-sizing cells. Each
/// assistant reply renders with a `DocumentView` that grows in place while the
/// mock reply streams in; its cell resizes automatically.
final class LLMChatViewController: UIViewController {

  private typealias DataSource = UICollectionViewDiffableDataSource<Int, UUID>

  private let viewModel = LLMChatViewModel()
  private let interactor = LLMChatInteractor()
  private lazy var collectionView = UICollectionView(frame: .zero, collectionViewLayout: Self.makeLayout())
  private lazy var dataSource = makeDataSource()
  private let composer = MessageComposerView()
  private var renderedContents: [UUID: ChatMessage.Content] = [:]
  private var cancellables = Set<AnyCancellable>()

  override func viewDidLoad() {
    super.viewDidLoad()
    title = "LLM Chat"
    navigationItem.largeTitleDisplayMode = .never
    view.backgroundColor = .systemBackground

    collectionView.backgroundColor = .clear
    collectionView.keyboardDismissMode = .interactive
    // Lets a cell resize when its DocumentView grows (the default on iOS 16+).
    collectionView.selfSizingInvalidation = .enabled
    composer.onSend = { [weak self] text in
      self?.send(text)
    }

    for subview in [collectionView, composer] {
      subview.translatesAutoresizingMaskIntoConstraints = false
      view.addSubview(subview)
    }
    NSLayoutConstraint.activate([
      collectionView.topAnchor.constraint(equalTo: view.topAnchor),
      collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      collectionView.bottomAnchor.constraint(equalTo: composer.topAnchor),
      composer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      composer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      composer.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor)
    ])

    viewModel.$messages
      .sink { [weak self] messages in self?.render(messages) }
      .store(in: &cancellables)

    Task { [interactor, viewModel] in
      await interactor.loadGreetingIfNeeded(into: viewModel)
    }
  }

  private static func makeLayout() -> UICollectionViewLayout {
    UICollectionViewCompositionalLayout { _, _ in
      let size = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(80))
      let group = NSCollectionLayoutGroup.vertical(layoutSize: size, subitems: [NSCollectionLayoutItem(layoutSize: size)])
      let section = NSCollectionLayoutSection(group: group)
      section.interGroupSpacing = 16
      section.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
      return section
    }
  }

  private func makeDataSource() -> DataSource {
    let userCell = UICollectionView.CellRegistration<UserMessageCell, UUID> { [weak self] cell, _, id in
      guard case .user(let text)? = self?.renderedContents[id] else { return }
      cell.configure(text: text)
    }
    let assistantCell = UICollectionView.CellRegistration<AssistantMessageCell, UUID> { [weak self] cell, _, id in
      guard let self, case .assistant(let document)? = self.renderedContents[id] else { return }
      cell.configure(document: document, config: self.interactor.markdownConfig)
    }
    return DataSource(collectionView: collectionView) { [weak self] collectionView, indexPath, id in
      if case .user? = self?.renderedContents[id] {
        return collectionView.dequeueConfiguredReusableCell(using: userCell, for: indexPath, item: id)
      }
      return collectionView.dequeueConfiguredReusableCell(using: assistantCell, for: indexPath, item: id)
    }
  }

  /// Appends new messages and reconfigures the cells of messages whose content
  /// changed, which updates their `DocumentView` in place.
  private func render(_ messages: [ChatMessage]) {
    let wasNearBottom = isNearBottom
    var snapshot = dataSource.snapshot()
    if snapshot.numberOfSections == 0 {
      snapshot.appendSections([0])
    }
    let existingIDs = Set(snapshot.itemIdentifiers)
    let newIDs = messages.map(\.id).filter { !existingIDs.contains($0) }
    let changedIDs = messages.filter { existingIDs.contains($0.id) && renderedContents[$0.id] != $0.content }.map(\.id)
    renderedContents = Dictionary(uniqueKeysWithValues: messages.map { ($0.id, $0.content) })

    snapshot.appendItems(newIDs)
    snapshot.reconfigureItems(changedIDs)
    dataSource.apply(snapshot, animatingDifferences: false)

    if !newIDs.isEmpty || wasNearBottom {
      // Scroll after the self-sizing pass has resized the updated cells.
      DispatchQueue.main.async { [weak self] in
        self?.scrollToBottom(animated: !newIDs.isEmpty)
      }
    }
  }

  private var isNearBottom: Bool {
    let visibleBottom = collectionView.contentOffset.y + collectionView.bounds.height - collectionView.adjustedContentInset.bottom
    return collectionView.contentSize.height - visibleBottom <= 40
  }

  private func scrollToBottom(animated: Bool) {
    collectionView.layoutIfNeeded()
    let insets = collectionView.adjustedContentInset
    let bottomOffset = max(-insets.top, collectionView.contentSize.height - collectionView.bounds.height + insets.bottom)
    collectionView.setContentOffset(CGPoint(x: 0, y: bottomOffset), animated: animated)
  }

  private func send(_ text: String) {
    viewModel.draft = text
    Task { [interactor, viewModel] in
      await interactor.send(into: viewModel)
    }
  }
}
