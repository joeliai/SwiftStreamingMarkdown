//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import Foundation

/// An assistant reply that the chat shows with a native view instead of
/// Markdown.
enum ChatWidget: Equatable {
  /// A photo loaded asynchronously from `url`. `description` is its
  /// accessibility label.
  case image(url: URL, description: String)
  /// An interactive map centered on a place.
  case map(Place)
  /// A card with a stock's price that expands to show more figures.
  case stockQuote(StockQuote)

  struct Place: Equatable {
    let name: String
    let latitude: Double
    let longitude: Double
    /// Places around this one, which the map can add on request.
    var nearby: [Place] = []
  }

  struct StockQuote: Equatable {
    let symbol: String
    let companyName: String
    let previousClose: Double
    /// Prices through the trading day; the last one is the current price.
    let intradayPrices: [Double]
    let volume: Int
    let marketCap: Double
    let priceEarningsRatio: Double

    var price: Double { intradayPrices.last ?? previousClose }
    var change: Double { price - previousClose }
    /// The change as a fraction of the previous close.
    var relativeChange: Double { change / previousClose }
    var open: Double { intradayPrices.first ?? previousClose }
    var high: Double { intradayPrices.max() ?? price }
    var low: Double { intradayPrices.min() ?? price }
  }
}
