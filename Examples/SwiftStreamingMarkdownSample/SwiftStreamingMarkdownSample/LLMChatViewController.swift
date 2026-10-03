//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import Combine
import SwiftStreamingMarkdown
import UIKit

/// A chat transcript in a `UICollectionView` with self-sizing cells. Each
/// message the user sends is pinned to the top of the screen, and a thinking
/// indicator shows below it until the mock reply arrives. Markdown replies
/// render with a `DocumentView` that grows in place as the reply streams in;
/// its cell resizes automatically. Other replies are native views: a photo
/// loaded from the web, a map, and an expandable stock card.
final class LLMChatViewController: UIViewController {

  private typealias DataSource = UICollectionViewDiffableDataSource<Int, UUID>

  private let viewModel = LLMChatViewModel()
  private let interactor = LLMChatInteractor()
  private lazy var layout = Self.makeLayout()
  private lazy var collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
  private lazy var dataSource = makeDataSource()
  private let composer = MessageComposerView()
  private var renderedContents: [UUID: ChatMessage.Content] = [:]
  /// Stock cards and maps the user expanded, so that they stay expanded when
  /// their cells are reused.
  private var expandedWidgets: Set<UUID> = []
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

  private static func makeLayout() -> ChatLayout {
    ChatLayout { _, _ in
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
    let imageCell = UICollectionView.CellRegistration<ImageMessageCell, UUID> { [weak self] cell, _, id in
      guard case .widget(.image(let url, let description))? = self?.renderedContents[id] else { return }
      cell.configure(url: url, description: description)
    }
    let mapCell = UICollectionView.CellRegistration<MapMessageCell, UUID> { [weak self] cell, _, id in
      guard let self, case .widget(.map(let place))? = self.renderedContents[id] else { return }
      cell.configure(place: place, isExpanded: self.expandedWidgets.contains(id))
      cell.onExpandedChange = self.expansionHandler(for: id)
    }
    let stockQuoteCell = UICollectionView.CellRegistration<StockQuoteCell, UUID> { [weak self] cell, _, id in
      guard let self, case .widget(.stockQuote(let quote))? = self.renderedContents[id] else { return }
      cell.configure(quote: quote, isExpanded: self.expandedWidgets.contains(id))
      cell.onExpandedChange = self.expansionHandler(for: id)
    }
    let thinkingCell = UICollectionView.CellRegistration<ThinkingMessageCell, UUID> { cell, _, _ in
      cell.startAnimating()
    }
    return DataSource(collectionView: collectionView) { [weak self] collectionView, indexPath, id in
      switch self?.renderedContents[id].map(CellKind.init) {
      case .user?:
        return collectionView.dequeueConfiguredReusableCell(using: userCell, for: indexPath, item: id)
      case .thinking?:
        return collectionView.dequeueConfiguredReusableCell(using: thinkingCell, for: indexPath, item: id)
      case .image?:
        return collectionView.dequeueConfiguredReusableCell(using: imageCell, for: indexPath, item: id)
      case .map?:
        return collectionView.dequeueConfiguredReusableCell(using: mapCell, for: indexPath, item: id)
      case .stockQuote?:
        return collectionView.dequeueConfiguredReusableCell(using: stockQuoteCell, for: indexPath, item: id)
      case .markdown?, nil:
        return collectionView.dequeueConfiguredReusableCell(using: assistantCell, for: indexPath, item: id)
      }
    }
  }

  /// Records when the user expands or collapses the widget of message `id`.
  private func expansionHandler(for id: UUID) -> (Bool) -> Void {
    { [weak self] isExpanded in
      if isExpanded {
        self?.expandedWidgets.insert(id)
      } else {
        self?.expandedWidgets.remove(id)
      }
    }
  }

  /// Appends new messages and updates the cells of messages whose content
  /// changed: in place when the same kind of cell still shows the content,
  /// such as a `DocumentView` that grows as a reply streams in, or with a new
  /// cell when a reply replaces its thinking indicator. A newly sent user
  /// message is scrolled to the top.
  private func render(_ messages: [ChatMessage]) {
    var snapshot = dataSource.snapshot()
    if snapshot.numberOfSections == 0 {
      snapshot.appendSections([0])
    }
    let existingIDs = Set(snapshot.itemIdentifiers)
    let newIDs = messages.map(\.id).filter { !existingIDs.contains($0) }
    var reconfiguredIDs: [UUID] = []
    var reloadedIDs: [UUID] = []
    for message in messages where existingIDs.contains(message.id) {
      guard let oldContent = renderedContents[message.id], oldContent != message.content else { continue }
      if CellKind(oldContent) == CellKind(message.content) {
        reconfiguredIDs.append(message.id)
      } else {
        reloadedIDs.append(message.id)
      }
    }
    renderedContents = Dictionary(uniqueKeysWithValues: messages.map { ($0.id, $0.content) })

    snapshot.appendItems(newIDs)
    snapshot.reconfigureItems(reconfiguredIDs)
    snapshot.reloadItems(reloadedIDs)

    let sentMessageID = newIDs.last { id in
      guard case .user? = renderedContents[id] else { return false }
      return true
    }
    if let sentMessageID, let index = snapshot.indexOfItem(sentMessageID) {
      // Pin before applying, so that the update sizes the content for the pin.
      layout.pinnedIndexPath = IndexPath(item: index, section: 0)
    }
    dataSource.apply(snapshot, animatingDifferences: false)

    if sentMessageID != nil {
      scrollToPinnedMessage()
    }
  }

  private func scrollToPinnedMessage() {
    collectionView.layoutIfNeeded()
    if let offset = layout.pinnedContentOffset {
      collectionView.setContentOffset(offset, animated: true)
    }
  }

  private func send(_ text: String) {
    viewModel.draft = text
    Task { [interactor, viewModel] in
      await interactor.send(into: viewModel)
    }
  }

  /// The kind of cell that shows each kind of content. A message whose
  /// content changes kind needs a new cell.
  private enum CellKind {
    case user, thinking, markdown, image, map, stockQuote

    init(_ content: ChatMessage.Content) {
      switch content {
      case .user: self = .user
      case .thinking: self = .thinking
      case .assistant: self = .markdown
      case .widget(.image): self = .image
      case .widget(.map): self = .map
      case .widget(.stockQuote): self = .stockQuote
      }
    }
  }

  /// While a message is pinned, keeps the content tall enough to scroll that
  /// message to the top of the visible area, however short the content below
  /// it is. The content's height then stays the same as a reply streams in
  /// below the message, so the message stays where it is.
  private final class ChatLayout: UICollectionViewCompositionalLayout {
    /// Space between the pinned message and the top of the visible area;
    /// matches the section's top inset.
    private static let pinnedMessageTopMargin: CGFloat = 16

    var pinnedIndexPath: IndexPath?

    /// The content offset that shows the pinned message at the top.
    var pinnedContentOffset: CGPoint? {
      guard let collectionView, let pinnedIndexPath,
            let frame = layoutAttributesForItem(at: pinnedIndexPath)?.frame else { return nil }
      return CGPoint(x: 0, y: frame.minY - Self.pinnedMessageTopMargin - collectionView.adjustedContentInset.top)
    }

    override var collectionViewContentSize: CGSize {
      var size = super.collectionViewContentSize
      if let collectionView, let offset = pinnedContentOffset {
        let visibleBottom = offset.y + collectionView.bounds.height - collectionView.adjustedContentInset.bottom
        size.height = max(size.height, visibleBottom)
      }
      return size
    }

    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
      // The content's height depends on the visible height.
      newBounds.height != collectionView?.bounds.height || super.shouldInvalidateLayout(forBoundsChange: newBounds)
    }
  }
}
