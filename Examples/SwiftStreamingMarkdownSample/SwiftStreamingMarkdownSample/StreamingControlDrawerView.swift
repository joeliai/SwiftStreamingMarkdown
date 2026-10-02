//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import Combine
import UIKit

/// The bottom drawer of the demonstration screen. Expanded, it shows playback
/// controls and live streaming metrics; collapsed, a small chevron button.
/// Swipe vertically to toggle it.
final class StreamingControlDrawerView: UIView {

  private let viewModel: DemonstrationViewModel
  private let listener: LoggingMarkdownListener
  private let panel: StreamingControlPanelView
  private let expandButton = UIButton(type: .system)
  private let expandButtonBackground = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
  private var cancellables = Set<AnyCancellable>()
  private var isShowingPanel: Bool?

  init(viewModel: DemonstrationViewModel, listener: LoggingMarkdownListener, isStreaming: Bool) {
    self.viewModel = viewModel
    self.listener = listener
    self.panel = StreamingControlPanelView(viewModel: viewModel, listener: listener, isStreaming: isStreaming)
    super.init(frame: .zero)

    panel.translatesAutoresizingMaskIntoConstraints = false
    addSubview(panel)

    expandButtonBackground.layer.cornerRadius = 22
    expandButtonBackground.layer.cornerCurve = .continuous
    expandButtonBackground.clipsToBounds = true
    expandButtonBackground.isUserInteractionEnabled = false
    expandButton.insertSubview(expandButtonBackground, at: 0)
    expandButton.setImage(
      UIImage(systemName: "chevron.up", withConfiguration: UIImage.SymbolConfiguration(textStyle: .headline, scale: .default)),
      for: .normal
    )
    expandButton.tintColor = .label
    expandButton.accessibilityLabel = "Show streaming controls"
    expandButton.addAction(UIAction { [weak self] _ in self?.setPresented(true) }, for: .touchUpInside)
    expandButton.translatesAutoresizingMaskIntoConstraints = false
    expandButtonBackground.translatesAutoresizingMaskIntoConstraints = false
    addSubview(expandButton)

    NSLayoutConstraint.activate([
      panel.topAnchor.constraint(equalTo: topAnchor),
      panel.leadingAnchor.constraint(equalTo: leadingAnchor),
      panel.trailingAnchor.constraint(equalTo: trailingAnchor),
      panel.bottomAnchor.constraint(equalTo: bottomAnchor),

      expandButton.centerXAnchor.constraint(equalTo: centerXAnchor),
      expandButton.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -8),
      expandButton.widthAnchor.constraint(equalToConstant: 96),
      expandButton.heightAnchor.constraint(equalToConstant: 44),
      expandButtonBackground.topAnchor.constraint(equalTo: expandButton.topAnchor),
      expandButtonBackground.bottomAnchor.constraint(equalTo: expandButton.bottomAnchor),
      expandButtonBackground.leadingAnchor.constraint(equalTo: expandButton.leadingAnchor),
      expandButtonBackground.trailingAnchor.constraint(equalTo: expandButton.trailingAnchor)
    ])

    addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(handleSwipe(_:))))

    viewModel.$isControlDrawerPresented
      .removeDuplicates()
      .sink { [weak self] isPresented in self?.showPanel(isPresented) }
      .store(in: &cancellables)
  }

  required init?(coder: NSCoder) {
    nil
  }

  override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
    // Let touches outside the visible control fall through to the content.
    let visibleView: UIView = isShowingPanel == true ? panel : expandButton
    return visibleView.frame.contains(point)
  }

  private func setPresented(_ isPresented: Bool) {
    viewModel.isControlDrawerPresented = isPresented
  }

  private func showPanel(_ isPresented: Bool) {
    let isFirstUpdate = isShowingPanel == nil
    isShowingPanel = isPresented
    let changes = {
      self.panel.alpha = isPresented ? 1 : 0
      self.panel.transform = isPresented ? .identity : CGAffineTransform(translationX: 0, y: 40)
      self.expandButton.alpha = isPresented ? 0 : 1
      self.expandButton.transform = isPresented ? CGAffineTransform(translationX: 0, y: 40) : .identity
    }
    if isFirstUpdate {
      changes()
    } else {
      UIView.animate(withDuration: 0.28, delay: 0, usingSpringWithDamping: 0.86, initialSpringVelocity: 0, animations: changes)
    }
  }

  @objc private func handleSwipe(_ recognizer: UIPanGestureRecognizer) {
    guard recognizer.state == .ended else { return }
    let translation = recognizer.translation(in: self).y
    guard abs(translation) > 28 else { return }
    setPresented(translation < 0)
  }
}

// MARK: - Panel

/// Playback, follow-scrolling, and speed controls above the live metrics.
private final class StreamingControlPanelView: UIView {

  private let viewModel: DemonstrationViewModel
  private let listener: LoggingMarkdownListener
  private let isStreaming: Bool

  private let replayButton = ControlButton(systemImage: "arrow.counterclockwise")
  private let playPauseButton = ControlButton(systemImage: "pause.fill")
  private let fastForwardButton = ControlButton(systemImage: "forward.end.fill")
  private let followButton = ControlButton(systemImage: "arrow.down")
  private let speedButtons: [(speed: StreamingSpeed, button: ControlButton)] = [
    (.slow, ControlButton(systemImage: "tortoise.fill")),
    (.normal, ControlButton(systemImage: "figure.walk")),
    (.fast, ControlButton(systemImage: "hare.fill"))
  ]
  private let progressView = UIProgressView(progressViewStyle: .default)
  private var metricLabels: [String: UILabel] = [:]
  private var cancellables = Set<AnyCancellable>()

  private static let metricTitles = ["Chars", "Chunks", "Renders", "Elapsed", "Chars/sec", "Chunks/sec", "Render lag", "State"]

  init(viewModel: DemonstrationViewModel, listener: LoggingMarkdownListener, isStreaming: Bool) {
    self.viewModel = viewModel
    self.listener = listener
    self.isStreaming = isStreaming
    super.init(frame: .zero)
    buildLayout()
    bindActions()

    // `objectWillChange` fires before a change; refresh once it has landed.
    viewModel.objectWillChange
      .merge(with: listener.objectWillChange)
      .receive(on: DispatchQueue.main)
      .sink { [weak self] _ in self?.refresh() }
      .store(in: &cancellables)
    refresh()
  }

  required init?(coder: NSCoder) {
    nil
  }

  private func buildLayout() {
    let background = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
    background.layer.cornerRadius = 18
    background.layer.cornerCurve = .continuous
    background.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
    background.clipsToBounds = true

    let grabber = UIButton(type: .custom)
    let grabberCapsule = UIView()
    grabberCapsule.backgroundColor = UIColor.secondaryLabel.withAlphaComponent(0.35)
    grabberCapsule.layer.cornerRadius = 2.5
    grabberCapsule.isUserInteractionEnabled = false
    grabberCapsule.translatesAutoresizingMaskIntoConstraints = false
    grabber.addSubview(grabberCapsule)
    grabber.accessibilityLabel = "Hide streaming controls"
    grabber.addAction(UIAction { [weak self] _ in self?.viewModel.isControlDrawerPresented = false }, for: .touchUpInside)

    let playback = equalStack([replayButton, playPauseButton, fastForwardButton])
    let speeds = equalStack(speedButtons.map(\.button))
    let follow = UIView()
    follow.addSubview(followButton)
    followButton.translatesAutoresizingMaskIntoConstraints = false
    let controls = UIStackView(arrangedSubviews: [playback, divider(), follow, divider(), speeds])
    controls.alignment = .center
    controls.spacing = 10

    let metrics = UIStackView(arrangedSubviews: [
      metricRow(Array(Self.metricTitles[0..<4])),
      metricRow(Array(Self.metricTitles[4..<8]))
    ])
    metrics.axis = .vertical
    metrics.spacing = 8

    let content = UIStackView(arrangedSubviews: [grabber, controls, progressView, metrics])
    content.axis = .vertical
    content.spacing = 12
    content.setCustomSpacing(8, after: progressView)

    for view in [background, content] {
      view.translatesAutoresizingMaskIntoConstraints = false
      addSubview(view)
    }
    NSLayoutConstraint.activate([
      background.topAnchor.constraint(equalTo: topAnchor, constant: 8),
      background.leadingAnchor.constraint(equalTo: leadingAnchor),
      background.trailingAnchor.constraint(equalTo: trailingAnchor),
      background.bottomAnchor.constraint(equalTo: bottomAnchor),

      content.topAnchor.constraint(equalTo: background.topAnchor, constant: 6),
      content.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
      content.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
      content.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -12),

      grabber.heightAnchor.constraint(equalToConstant: 24),
      grabberCapsule.widthAnchor.constraint(equalToConstant: 42),
      grabberCapsule.heightAnchor.constraint(equalToConstant: 5),
      grabberCapsule.centerXAnchor.constraint(equalTo: grabber.centerXAnchor),
      grabberCapsule.centerYAnchor.constraint(equalTo: grabber.centerYAnchor),

      follow.widthAnchor.constraint(equalToConstant: 48),
      follow.heightAnchor.constraint(equalTo: followButton.heightAnchor),
      followButton.centerXAnchor.constraint(equalTo: follow.centerXAnchor),
      followButton.centerYAnchor.constraint(equalTo: follow.centerYAnchor),
      playback.widthAnchor.constraint(equalTo: speeds.widthAnchor)
    ])
  }

  private func equalStack(_ views: [UIView]) -> UIStackView {
    let containers = views.map { button -> UIView in
      let container = UIView()
      button.translatesAutoresizingMaskIntoConstraints = false
      container.addSubview(button)
      NSLayoutConstraint.activate([
        button.centerXAnchor.constraint(equalTo: container.centerXAnchor),
        button.topAnchor.constraint(equalTo: container.topAnchor),
        button.bottomAnchor.constraint(equalTo: container.bottomAnchor)
      ])
      return container
    }
    let stack = UIStackView(arrangedSubviews: containers)
    stack.distribution = .fillEqually
    stack.spacing = 4
    return stack
  }

  private func divider() -> UIView {
    let divider = UIView()
    divider.backgroundColor = .separator
    divider.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      divider.widthAnchor.constraint(equalToConstant: 1),
      divider.heightAnchor.constraint(equalToConstant: 24)
    ])
    return divider
  }

  private func metricRow(_ titles: [String]) -> UIStackView {
    let cells = titles.map { title -> UIView in
      let titleLabel = UILabel()
      titleLabel.text = title
      titleLabel.font = .preferredFont(forTextStyle: .caption2)
      titleLabel.textColor = .secondaryLabel
      titleLabel.textAlignment = .center
      let valueLabel = UILabel()
      valueLabel.font = .monospacedDigitSystemFont(ofSize: UIFont.preferredFont(forTextStyle: .caption1).pointSize, weight: .regular)
      valueLabel.textAlignment = .center
      valueLabel.adjustsFontSizeToFitWidth = true
      valueLabel.minimumScaleFactor = 0.75
      metricLabels[title] = valueLabel
      let stack = UIStackView(arrangedSubviews: [titleLabel, valueLabel])
      stack.axis = .vertical
      stack.spacing = 2
      return stack
    }
    let row = UIStackView(arrangedSubviews: cells)
    row.distribution = .fillEqually
    row.spacing = 8
    return row
  }

  private func bindActions() {
    replayButton.accessibilityLabel = "Replay stream"
    replayButton.addAction(UIAction { [weak self] _ in self?.viewModel.replay() }, for: .touchUpInside)
    playPauseButton.addAction(UIAction { [weak self] _ in self?.viewModel.togglePlayback() }, for: .touchUpInside)
    fastForwardButton.accessibilityLabel = "Fast forward stream"
    fastForwardButton.addAction(UIAction { [weak self] _ in self?.viewModel.fastForward() }, for: .touchUpInside)
    followButton.addAction(UIAction { [weak self] _ in self?.listener.toggleFollowScrolling() }, for: .touchUpInside)
    for (speed, button) in speedButtons {
      button.accessibilityLabel = "\(speed.displayName) streaming speed"
      button.addAction(UIAction { [weak self] _ in self?.viewModel.speed = speed }, for: .touchUpInside)
    }
  }

  private func refresh() {
    let viewModel = self.viewModel
    playPauseButton.configure(
      systemImage: viewModel.isPlaying ? "pause.fill" : "play.fill",
      isSelected: viewModel.isPlaying,
      isEnabled: isStreaming && !viewModel.isComplete
    )
    playPauseButton.accessibilityLabel = viewModel.isPlaying ? "Pause stream" : "Play stream"
    fastForwardButton.configure(isSelected: false, isEnabled: isStreaming && !viewModel.isComplete)
    followButton.configure(isSelected: listener.followsStreamingMarkdown, isEnabled: isStreaming)
    followButton.accessibilityLabel = listener.followsStreamingMarkdown ? "Disable follow scrolling" : "Enable follow scrolling"
    for (speed, button) in speedButtons {
      button.configure(isSelected: viewModel.speed == speed, isEnabled: isStreaming)
    }

    progressView.progress = Float(viewModel.progress)
    let values = [
      "Chars": "\(viewModel.streamedCharacters)/\(viewModel.totalCharacters)",
      "Chunks": "\(viewModel.chunkCount)",
      "Renders": "\(viewModel.renderCount)",
      "Elapsed": "\(Self.numberText(viewModel.elapsedTime))s",
      "Chars/sec": Self.numberText(viewModel.charactersPerSecond),
      "Chunks/sec": Self.numberText(viewModel.chunksPerSecond),
      "Render lag": viewModel.lastRenderLatency.map { "\(Self.numberText($0 * 1_000))ms" } ?? "—",
      "State": stateText
    ]
    for (title, value) in values {
      metricLabels[title]?.text = value
    }
  }

  private var stateText: String {
    if viewModel.isComplete {
      return "Done"
    }
    if isStreaming {
      return viewModel.isPlaying ? "Playing" : "Paused"
    }
    return "Static"
  }

  private static func numberText(_ value: Double) -> String {
    if value >= 100 {
      return String(format: "%.0f", value)
    }
    if value >= 10 {
      return String(format: "%.1f", value)
    }
    return String(format: "%.2f", value)
  }
}

// MARK: - Control button

/// A 44-point circular icon button that fills with the accent color when
/// selected.
private final class ControlButton: UIButton {

  init(systemImage: String) {
    super.init(frame: .zero)
    layer.cornerRadius = 22
    configure(systemImage: systemImage, isSelected: false, isEnabled: true)
    NSLayoutConstraint.activate([
      widthAnchor.constraint(equalToConstant: 44),
      heightAnchor.constraint(equalToConstant: 44)
    ])
  }

  required init?(coder: NSCoder) {
    nil
  }

  func configure(systemImage: String? = nil, isSelected: Bool, isEnabled: Bool) {
    if let systemImage {
      let configuration = UIImage.SymbolConfiguration(textStyle: .caption1, scale: .default)
        .applying(UIImage.SymbolConfiguration(weight: .semibold))
      setImage(UIImage(systemName: systemImage, withConfiguration: configuration), for: .normal)
    }
    self.isEnabled = isEnabled
    alpha = isEnabled ? 1 : 0.4
    tintColor = isSelected ? .white : .label
    backgroundColor = isSelected ? Self.accentColor : UIColor.label.withAlphaComponent(0.08)
  }

  private static let accentColor = UIColor(named: "AccentColor") ?? .systemBlue
}
