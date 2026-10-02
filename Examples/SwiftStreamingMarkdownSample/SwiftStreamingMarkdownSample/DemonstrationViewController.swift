//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import Combine
import SwiftStreamingMarkdown
import UIKit

/// Renders one demonstration fixture inside a scroll view, either streamed
/// (`StreamedMarkdownView`) or all at once (`MarkdownView`), with a drawer of
/// playback controls and live metrics.
final class DemonstrationViewController: UIViewController, UIScrollViewDelegate {

  private static let contentMaxWidth: CGFloat = 760
  private static let horizontalPadding: CGFloat = 28
  private static let verticalPadding: CGFloat = 16

  private let demonstration: Demonstration
  private let markdownText: String
  private let viewModel: DemonstrationViewModel
  private let listener = LoggingMarkdownListener()
  private let settings = SampleSettings.shared

  private let scrollView = UIScrollView()
  private var markdownView: UIView?
  private var bottomPaddingConstraint: NSLayoutConstraint?
  private var drawer: StreamingControlDrawerView?
  private var renderedSettings: (isStreamed: Bool, theme: SampleMarkdownTheme)?
  private var settingsObserver: NSObjectProtocol?
  private var cancellables = Set<AnyCancellable>()

  init(demonstration: Demonstration, markdownText: String) {
    self.demonstration = demonstration
    self.markdownText = markdownText
    self.viewModel = DemonstrationViewModel(text: markdownText)
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    nil
  }

  deinit {
    if let settingsObserver {
      NotificationCenter.default.removeObserver(settingsObserver)
    }
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    title = demonstration.rawValue
    navigationItem.largeTitleDisplayMode = .never

    scrollView.delegate = self
    scrollView.alwaysBounceVertical = true
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(scrollView)
    NSLayoutConstraint.activate([
      scrollView.topAnchor.constraint(equalTo: view.topAnchor),
      scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
    ])

    listener.viewModel = viewModel
    listener.scrollToBottom = { [weak self] duration in
      self?.scrollToBottom(duration: duration)
    }

    viewModel.$isControlDrawerPresented
      .dropFirst()
      .removeDuplicates()
      .sink { [weak self] isPresented in self?.controlDrawerPresentationChanged(isPresented) }
      .store(in: &cancellables)
    // Replay restarts the stream from the beginning.
    viewModel.$streamID
      .dropFirst()
      .sink { [weak self] _ in self?.restartStream() }
      .store(in: &cancellables)

    settingsObserver = NotificationCenter.default.addObserver(
      forName: SampleSettings.didChangeNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.applySettings()
    }
    applySettings()
  }

  // MARK: - Settings

  private func applySettings() {
    let isStreamed = settings.preferStreamedMarkdown
    let theme = settings.markdownTheme
    view.backgroundColor = theme.backgroundColor(for: demonstration)
    configureMenu()

    guard renderedSettings?.isStreamed != isStreamed || renderedSettings?.theme != theme else { return }
    renderedSettings = (isStreamed, theme)
    showMarkdown(isStreamed: isStreamed, theme: theme)
    showControlDrawer(isStreaming: isStreamed)
    listener.isStreamingActive = isStreamed
    if isStreamed {
      viewModel.play()
    }
  }

  private func configureMenu() {
    let themeActions = SampleMarkdownTheme.allCases.map { theme in
      UIAction(title: theme.displayName, state: theme == settings.markdownTheme ? .on : .off) { [weak self] _ in
        self?.settings.markdownTheme = theme
      }
    }
    let appearanceActions = AppearanceMode.allCases.map { mode in
      UIAction(title: mode.displayName, state: mode == settings.appearanceMode ? .on : .off) { [weak self] _ in
        self?.settings.appearanceMode = mode
      }
    }
    let menu = UIMenu(children: [
      UIMenu(title: "Markdown Theme", options: .displayInline, children: themeActions),
      UIMenu(title: "Appearance", options: .displayInline, children: appearanceActions)
    ])
    if let item = navigationItem.rightBarButtonItem {
      item.menu = menu
    } else {
      let item = UIBarButtonItem(image: UIImage(systemName: "circle.righthalf.filled"), menu: menu)
      item.accessibilityLabel = "Appearance"
      navigationItem.rightBarButtonItem = item
    }
  }

  // MARK: - Content

  private func showMarkdown(isStreamed: Bool, theme: SampleMarkdownTheme) {
    markdownView?.removeFromSuperview()
    let config = demonstration.renderConfig(theme: theme, isStreaming: isStreamed)
    let markdownView: UIView
    if isStreamed {
      markdownView = StreamedMarkdownView(source: viewModel, config: config, listener: listener)
    } else {
      markdownView = MarkdownView(text: markdownText, config: config, listener: listener)
      viewModel.reset(totalCharacters: markdownText.count, mode: .staticMarkdown)
      viewModel.recordChunk(snapshotLength: markdownText.count, isFinal: true)
    }
    self.markdownView = markdownView

    // The Markdown view sizes itself through Auto Layout; the scroll view's
    // content height follows it.
    markdownView.translatesAutoresizingMaskIntoConstraints = false
    scrollView.addSubview(markdownView)
    let fullWidth = markdownView.widthAnchor.constraint(
      equalTo: scrollView.frameLayoutGuide.widthAnchor,
      constant: -Self.horizontalPadding * 2
    )
    fullWidth.priority = .defaultHigh
    let bottomPadding = markdownView.bottomAnchor.constraint(
      equalTo: scrollView.contentLayoutGuide.bottomAnchor,
      constant: -bottomPadding(isControlDrawerPresented: viewModel.isControlDrawerPresented)
    )
    bottomPaddingConstraint = bottomPadding
    NSLayoutConstraint.activate([
      markdownView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: Self.verticalPadding),
      bottomPadding,
      markdownView.centerXAnchor.constraint(equalTo: scrollView.frameLayoutGuide.centerXAnchor),
      markdownView.widthAnchor.constraint(lessThanOrEqualToConstant: Self.contentMaxWidth),
      markdownView.widthAnchor.constraint(
        lessThanOrEqualTo: scrollView.frameLayoutGuide.widthAnchor,
        constant: -Self.horizontalPadding * 2
      ),
      fullWidth
    ])
  }

  private func restartStream() {
    (markdownView as? StreamedMarkdownView)?.source = viewModel
  }

  private func showControlDrawer(isStreaming: Bool) {
    drawer?.removeFromSuperview()
    let drawer = StreamingControlDrawerView(viewModel: viewModel, listener: listener, isStreaming: isStreaming)
    drawer.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(drawer)
    NSLayoutConstraint.activate([
      drawer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      drawer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      drawer.bottomAnchor.constraint(equalTo: view.bottomAnchor)
    ])
    self.drawer = drawer
  }

  private func bottomPadding(isControlDrawerPresented: Bool) -> CGFloat {
    Self.verticalPadding + (isControlDrawerPresented ? 190 : 58)
  }

  private func controlDrawerPresentationChanged(_ isPresented: Bool) {
    bottomPaddingConstraint?.constant = -bottomPadding(isControlDrawerPresented: isPresented)
    UIView.animate(withDuration: 0.28, delay: 0, usingSpringWithDamping: 0.86, initialSpringVelocity: 0) {
      self.view.layoutIfNeeded()
    }
    guard isPresented, viewModel.isComplete, viewModel.isAtScrollBottom else { return }
    Task { @MainActor [weak self] in
      try? await Task.sleep(nanoseconds: 80_000_000)
      self?.listener.scrollToStreamingBottom(force: true)
    }
  }

  // MARK: - Scrolling

  private func scrollToBottom(duration: TimeInterval) {
    scrollView.layoutIfNeeded()
    let insets = scrollView.adjustedContentInset
    let bottomOffset = max(-insets.top, scrollView.contentSize.height - scrollView.bounds.height + insets.bottom)
    UIView.animate(withDuration: duration, delay: 0, options: [.curveLinear, .beginFromCurrentState, .allowUserInteraction]) {
      self.scrollView.contentOffset.y = bottomOffset
    }
  }

  func scrollViewDidScroll(_ scrollView: UIScrollView) {
    let visibleBottom = scrollView.contentOffset.y + scrollView.bounds.height - scrollView.adjustedContentInset.bottom
    let isAtBottom = scrollView.contentSize.height - visibleBottom <= 12
    if viewModel.isAtScrollBottom != isAtBottom {
      viewModel.isAtScrollBottom = isAtBottom
    }
  }
}
