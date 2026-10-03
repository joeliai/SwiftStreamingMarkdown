//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import UIKit

/// A stock reply: a card with a stock's price, its change since the previous
/// close, and an intraday chart. The card's button expands it, with
/// animation, to a taller chart and more figures.
final class StockQuoteCell: UICollectionViewCell {

  /// Called when the user expands or collapses the card.
  var onExpandedChange: ((Bool) -> Void)?

  private static let collapsedChartHeight: CGFloat = 56
  private static let expandedChartHeight: CGFloat = 150
  private static let statTitles = ["Open", "High", "Low", "Volume", "Market cap", "P/E ratio"]

  private let symbolLabel = UILabel()
  private let nameLabel = UILabel()
  private let priceLabel = UILabel()
  private let changeLabel = UILabel()
  private let chartView = SparklineView()
  private let statValueLabels = StockQuoteCell.statTitles.map { _ in UILabel() }
  private let detailsView = UIStackView()
  private let toggleButton = UIButton(configuration: .plain())
  private lazy var chartHeightConstraint = chartView.heightAnchor.constraint(equalToConstant: Self.collapsedChartHeight)
  private var isExpanded = false

  override init(frame: CGRect) {
    super.init(frame: frame)
    let card = UIView()
    card.backgroundColor = .secondarySystemBackground
    card.layer.cornerRadius = 20
    card.layer.cornerCurve = .continuous

    let content = UIStackView(arrangedSubviews: [makeHeader(), chartView, makeDetails(), makeFooter()])
    content.axis = .vertical
    content.spacing = 12
    chartView.isAccessibilityElement = true
    chartView.accessibilityLabel = "Intraday price chart"

    for view in [card, content] {
      view.translatesAutoresizingMaskIntoConstraints = false
    }
    contentView.addSubview(card)
    card.addSubview(content)
    // Below the required priority, so that it gives way to the estimated
    // height that a new cell starts with.
    let bottom = card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -14)
    bottom.priority = .required - 1
    NSLayoutConstraint.activate([
      card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
      bottom,
      card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
      card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
      content.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
      content.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -10),
      content.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
      content.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
      chartHeightConstraint
    ])
  }

  required init?(coder: NSCoder) {
    nil
  }

  override func prepareForReuse() {
    super.prepareForReuse()
    onExpandedChange = nil
    // Clear the previous quote, as if loading a different one.
    for label in [symbolLabel, nameLabel, priceLabel, changeLabel] + statValueLabels {
      label.text = nil
    }
    chartView.prices = []
    chartView.baseline = nil
    setExpanded(false, animated: false)
  }

  func configure(quote: ChatWidget.StockQuote, isExpanded: Bool) {
    let price = quote.price.formatted(.currency(code: "USD"))
    let change = quote.change.formatted(.number.precision(.fractionLength(2)).sign(strategy: .always()))
    let relativeChange = quote.relativeChange.formatted(.percent.precision(.fractionLength(2)).sign(strategy: .always()))
    let trendColor: UIColor = quote.change >= 0 ? .systemGreen : .systemRed
    symbolLabel.text = quote.symbol
    nameLabel.text = quote.companyName
    priceLabel.text = price
    changeLabel.text = "\(change) (\(relativeChange))"
    changeLabel.textColor = trendColor

    chartView.prices = quote.intradayPrices
    chartView.baseline = quote.previousClose
    chartView.lineColor = trendColor
    chartView.accessibilityValue = "From \(quote.open.formatted(.currency(code: "USD"))) to \(price)"

    let statValues = [
      quote.open.formatted(.currency(code: "USD")),
      quote.high.formatted(.currency(code: "USD")),
      quote.low.formatted(.currency(code: "USD")),
      quote.volume.formatted(.number.notation(.compactName).precision(.fractionLength(1))),
      quote.marketCap.formatted(.currency(code: "USD").notation(.compactName).precision(.fractionLength(2))),
      quote.priceEarningsRatio.formatted(.number.precision(.fractionLength(1)))
    ]
    for (label, value) in zip(statValueLabels, statValues) {
      label.text = value
    }
    setExpanded(isExpanded, animated: false)
  }

  // MARK: - Expanding

  private func toggleExpanded() {
    setExpanded(!isExpanded, animated: true)
    onExpandedChange?(isExpanded)
  }

  private func setExpanded(_ expanded: Bool, animated: Bool) {
    isExpanded = expanded
    toggleButton.configuration?.title = expanded ? "Show less" : "Show more"
    toggleButton.configuration?.image = UIImage(systemName: expanded ? "chevron.up" : "chevron.down")
    let applyChanges = {
      self.chartHeightConstraint.constant = expanded ? Self.expandedChartHeight : Self.collapsedChartHeight
      // Stack views miscount repeated hides of an arranged view, so only set
      // it when it changes.
      if self.detailsView.isHidden == expanded {
        self.detailsView.isHidden = !expanded
      }
      self.detailsView.alpha = expanded ? 1 : 0
    }
    guard animated else {
      applyChanges()
      return
    }
    animateResize(applyChanges)
  }

  // MARK: - Subviews

  private func makeHeader() -> UIView {
    symbolLabel.font = Self.font(.title3, weight: .bold)
    nameLabel.font = Self.font(.subheadline, weight: .regular)
    nameLabel.textColor = .secondaryLabel
    priceLabel.font = Self.font(.title3, weight: .semibold, monospacedDigits: true)
    changeLabel.font = Self.font(.subheadline, weight: .medium, monospacedDigits: true)
    for label in [symbolLabel, nameLabel, priceLabel, changeLabel] {
      label.adjustsFontForContentSizeCategory = true
    }

    let quote = Self.verticalStack([priceLabel, changeLabel], alignment: .trailing)
    quote.setContentHuggingPriority(.required, for: .horizontal)
    quote.setContentCompressionResistancePriority(.required, for: .horizontal)
    let header = UIStackView(arrangedSubviews: [Self.verticalStack([symbolLabel, nameLabel], alignment: .leading), quote])
    header.alignment = .top
    header.spacing = 12
    return header
  }

  private func makeDetails() -> UIView {
    let stats = zip(Self.statTitles, statValueLabels).map { title, valueLabel -> UIView in
      let titleLabel = UILabel()
      titleLabel.text = title
      titleLabel.font = .preferredFont(forTextStyle: .caption1)
      titleLabel.textColor = .secondaryLabel
      valueLabel.font = Self.font(.subheadline, weight: .semibold, monospacedDigits: true)
      for label in [titleLabel, valueLabel] {
        label.adjustsFontForContentSizeCategory = true
      }
      return Self.verticalStack([titleLabel, valueLabel], alignment: .leading)
    }
    detailsView.axis = .vertical
    detailsView.spacing = 12
    for rowStart in stride(from: 0, to: stats.count, by: 3) {
      let row = UIStackView(arrangedSubviews: Array(stats[rowStart..<min(rowStart + 3, stats.count)]))
      row.distribution = .fillEqually
      row.spacing = 12
      detailsView.addArrangedSubview(row)
    }
    detailsView.isHidden = true
    detailsView.alpha = 0
    return detailsView
  }

  private func makeFooter() -> UIView {
    let footnote = UILabel()
    footnote.text = "Sample data"
    footnote.font = .preferredFont(forTextStyle: .caption2)
    footnote.adjustsFontForContentSizeCategory = true
    footnote.textColor = .tertiaryLabel

    var configuration = UIButton.Configuration.plain()
    configuration.imagePlacement = .trailing
    configuration.imagePadding = 4
    configuration.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0)
    configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(textStyle: .footnote, scale: .small)
    configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
      var attributes = attributes
      attributes.font = Self.font(.subheadline, weight: .semibold)
      return attributes
    }
    toggleButton.configuration = configuration
    toggleButton.addAction(UIAction { [weak self] _ in self?.toggleExpanded() }, for: .touchUpInside)

    let footer = UIStackView(arrangedSubviews: [footnote, toggleButton])
    footer.alignment = .center
    footer.distribution = .equalSpacing
    return footer
  }

  private static func verticalStack(_ views: [UIView], alignment: UIStackView.Alignment) -> UIStackView {
    let stack = UIStackView(arrangedSubviews: views)
    stack.axis = .vertical
    stack.alignment = alignment
    stack.spacing = 2
    return stack
  }

  /// A system font for `style` that scales with Dynamic Type.
  private static func font(_ style: UIFont.TextStyle, weight: UIFont.Weight, monospacedDigits: Bool = false) -> UIFont {
    let defaultTraits = UITraitCollection(preferredContentSizeCategory: .large)
    let size = UIFont.preferredFont(forTextStyle: style, compatibleWith: defaultTraits).pointSize
    let font = monospacedDigits
      ? UIFont.monospacedDigitSystemFont(ofSize: size, weight: weight)
      : UIFont.systemFont(ofSize: size, weight: weight)
    return UIFontMetrics(forTextStyle: style).scaledFont(for: font)
  }

  // MARK: - SparklineView

  /// Draws prices as a line over a gradient fill, with a dashed line at the
  /// baseline price.
  private final class SparklineView: UIView {
    var prices: [Double] = [] {
      didSet { setNeedsDisplay() }
    }
    var baseline: Double? {
      didSet { setNeedsDisplay() }
    }
    var lineColor: UIColor = .systemGreen {
      didSet { setNeedsDisplay() }
    }

    override init(frame: CGRect) {
      super.init(frame: frame)
      isOpaque = false
      contentMode = .redraw
    }

    required init?(coder: NSCoder) {
      nil
    }

    override func draw(_ rect: CGRect) {
      let values = prices + [baseline].compactMap { $0 }
      guard prices.count > 1, let low = values.min(), let high = values.max(),
            let context = UIGraphicsGetCurrentContext() else {
        return
      }
      let plot = bounds.insetBy(dx: 1, dy: 2)
      let range = max(high - low, .ulpOfOne)
      func yPosition(of value: Double) -> CGFloat {
        plot.maxY - plot.height * CGFloat((value - low) / range)
      }
      let points = prices.enumerated().map { index, price in
        CGPoint(x: plot.minX + plot.width * CGFloat(index) / CGFloat(prices.count - 1), y: yPosition(of: price))
      }
      guard let first = points.first, let last = points.last else { return }

      let line = UIBezierPath()
      line.move(to: first)
      points.dropFirst().forEach(line.addLine(to:))

      let fill = UIBezierPath()
      fill.move(to: CGPoint(x: first.x, y: plot.maxY))
      points.forEach(fill.addLine(to:))
      fill.addLine(to: CGPoint(x: last.x, y: plot.maxY))
      fill.close()
      context.saveGState()
      fill.addClip()
      let colors = [lineColor.withAlphaComponent(0.3).cgColor, lineColor.withAlphaComponent(0).cgColor] as CFArray
      if let gradient = CGGradient(colorsSpace: nil, colors: colors, locations: [0, 1]) {
        context.drawLinearGradient(
          gradient,
          start: CGPoint(x: 0, y: plot.minY),
          end: CGPoint(x: 0, y: plot.maxY),
          options: []
        )
      }
      context.restoreGState()

      if let baseline {
        let baselinePath = UIBezierPath()
        baselinePath.move(to: CGPoint(x: plot.minX, y: yPosition(of: baseline)))
        baselinePath.addLine(to: CGPoint(x: plot.maxX, y: yPosition(of: baseline)))
        baselinePath.setLineDash([3, 3], count: 2, phase: 0)
        UIColor.separator.setStroke()
        baselinePath.stroke()
      }

      line.lineWidth = 2
      line.lineJoinStyle = .round
      line.lineCapStyle = .round
      lineColor.setStroke()
      line.stroke()
    }
  }
}
