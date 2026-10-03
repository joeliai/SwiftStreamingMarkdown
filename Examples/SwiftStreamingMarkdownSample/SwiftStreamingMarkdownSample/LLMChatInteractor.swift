//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import Foundation
import SwiftStreamingMarkdown

final class LLMChatInteractor {
  /// Shared render config, also handed to `DocumentView` so on-screen styling
  /// matches how each `RenderableDocument` was parsed.
  let markdownConfig = MarkdownRenderConfig.default
    .withShouldAnimateText(value: true)
    .withImageConfig(ImageConfig(
      enabled: true,
      allowedImageTypes: [.assetCatalog, .bundledResource]
    ))

  private let parser = MarkdownParserImpl()
  private var nextResponseIndex = 0
  private var nextPhotoIndex = 0
  private var nextPlaceIndex = 0

  /// How long a reply takes to start arriving, as if from a server.
  private static let responseDelay: Duration = .milliseconds(1_500)

  /// Stream the greeting once, when the transcript is still empty.
  func loadGreetingIfNeeded(into viewModel: LLMChatViewModel) async {
    guard await viewModel.messages.isEmpty else { return }
    let messageID = await viewModel.appendAssistantMessage(.empty)
    await streamAssistantReply(markdown: Self.greeting, messageID: messageID, into: viewModel)
  }

  /// Send the current draft as a user message, show a thinking indicator
  /// while the reply is on its way, and then replace the indicator with the
  /// next mock response: streamed Markdown or a native view.
  func send(into viewModel: LLMChatViewModel) async {
    guard let text = await viewModel.consumeDraft() else { return }
    await viewModel.appendUserMessage(text)
    let replyID = await viewModel.appendThinkingMessage()

    let reply = nextReply()
    try? await Task.sleep(for: Self.responseDelay)
    switch reply {
    case .markdown(let markdown):
      await streamAssistantReply(markdown: markdown, messageID: replyID, into: viewModel)
    case .widget(let widget):
      await viewModel.updateAssistantMessage(id: replyID, widget: widget)
    }
  }

  /// The next mock reply in the rotation. Each native view gets new content,
  /// as replies from a server would.
  private func nextReply() -> Reply {
    let response = Self.mockResponses[nextResponseIndex]
    nextResponseIndex = (nextResponseIndex + 1) % Self.mockResponses.count
    switch response {
    case .markdown(let markdown):
      return .markdown(markdown)
    case .photo:
      let photo = Self.photos[nextPhotoIndex]
      nextPhotoIndex = (nextPhotoIndex + 1) % Self.photos.count
      return .widget(photo)
    case .map:
      let place = Self.places[nextPlaceIndex]
      nextPlaceIndex = (nextPlaceIndex + 1) % Self.places.count
      return .widget(.map(place))
    case .stockQuote:
      return .widget(.stockQuote(Self.makeStockQuote()))
    }
  }

  /// Simulate streaming by parsing progressively larger prefixes of `markdown`
  /// and updating the assistant message in place as its content grows.
  private func streamAssistantReply(markdown: String, messageID: UUID, into viewModel: LLMChatViewModel) async {
    let chunkSize = 3
    var endIndex = markdown.startIndex

    while endIndex < markdown.endIndex {
      if Task.isCancelled { return }

      endIndex = markdown.index(
        endIndex,
        offsetBy: chunkSize,
        limitedBy: markdown.endIndex
      ) ?? markdown.endIndex

      let snapshot = String(markdown[..<endIndex])
      let document = await parser.parse(text: snapshot, config: markdownConfig)
      await viewModel.updateAssistantMessage(id: messageID, document: document)

      if endIndex == markdown.endIndex { break }
      try? await Task.sleep(nanoseconds: 30_000_000)
    }
  }

  private static let greeting =
    "Hi! Ask me anything to see Markdown responses with rich content. A few replies are native views instead: a photo from the web, a map, and a stock card."

  private enum Reply {
    case markdown(String)
    case widget(ChatWidget)
  }

  private enum MockResponse {
    case markdown(String)
    case photo
    case map
    case stockQuote
  }

  /// Mock replies in the order they rotate. The native views come right after
  /// the introduction so that they are quick to reach.
  private static let mockResponses: [MockResponse] = [
    .markdown("""
    SwiftStreamingMarkdown is designed to render Markdown incrementally as an LLM response arrives. It supports headings, lists, tables, citations, code blocks, math, and more.

    You can learn more in the [project documentation](https://github.com/microsoft/SwiftStreamingMarkdown?citationMarker=9F742443&citationTitle=SwiftStreamingMarkdown&citationA11yValue=SwiftStreamingMarkdown%20GitHub%20repository&citationId=chat-doc-1&chatItemId=llm-chat).
    """),
    .photo,
    .map,
    .stockQuote,
    .markdown("""
    Here is an image loaded from the sample app's asset catalog:

    ![A mountain lake surrounded by trees](assets://Images/mountain-lake)
    """),
    .markdown("""
    A pre-parsed Markdown view only needs a few lines:

    ```swift
    import SwiftStreamingMarkdown
    import UIKit

    final class ResponseCell: UICollectionViewCell {
      private let documentView = DocumentView()

      func configure(with document: RenderableDocument) {
        documentView.renderableDocument = document
      }
    }
    ```
    """),
    .markdown("""
    Here is a quick feature comparison:

    | Content | Supported |
    | --- | --- |
    | Text styles | Yes |
    | Code blocks | Yes |
    | Citations | Yes |
    | Images | Yes |
    """),
    .markdown("""
    You can structure an answer with several Markdown elements:

    1. **Summarize** the request.
    2. Provide concise implementation details.
    3. Highlight identifiers such as `DocumentView`.

    > Mock responses rotate each time you send a message.
    """)
  ]

  /// Photos that photo replies rotate through, in a mix of aspect ratios.
  private static let photos = [
    photo("https://picsum.photos/id/1018/1200/800", "A road winding through green hills and cliffs under a misty sky"),
    photo("https://picsum.photos/id/1025/800/1000", "A pug wrapped in a plaid blanket on a forest path"),
    photo("https://picsum.photos/id/1069/1000/1000", "An orange jellyfish drifting in deep blue water"),
    photo("https://picsum.photos/id/1015/1200/800", "A fjord winding between rocky cliffs under a blue sky")
  ]

  /// Places that map replies rotate through.
  private static let places = [
    ChatWidget.Place(name: "Microsoft Campus", latitude: 47.6396, longitude: -122.1285, nearby: [
      ChatWidget.Place(name: "Redmond Technology Station", latitude: 47.6447, longitude: -122.1336),
      ChatWidget.Place(name: "Overlake Village Station", latitude: 47.6364, longitude: -122.1389)
    ]),
    ChatWidget.Place(name: "Space Needle", latitude: 47.6205, longitude: -122.3493, nearby: [
      ChatWidget.Place(name: "Museum of Pop Culture", latitude: 47.6215, longitude: -122.3481),
      ChatWidget.Place(name: "Chihuly Garden and Glass", latitude: 47.6206, longitude: -122.3506),
      ChatWidget.Place(name: "Climate Pledge Arena", latitude: 47.6221, longitude: -122.3542),
      ChatWidget.Place(name: "Pacific Science Center", latitude: 47.6193, longitude: -122.3510)
    ]),
    ChatWidget.Place(name: "Pike Place Market", latitude: 47.6097, longitude: -122.3421, nearby: [
      ChatWidget.Place(name: "Seattle Aquarium", latitude: 47.6077, longitude: -122.3431),
      ChatWidget.Place(name: "Seattle Great Wheel", latitude: 47.6062, longitude: -122.3426),
      ChatWidget.Place(name: "Seattle Art Museum", latitude: 47.6073, longitude: -122.3381)
    ])
  ]

  private static func photo(_ urlString: String, _ description: String) -> ChatWidget {
    guard let url = URL(string: urlString) else {
      preconditionFailure("The mock photo URL is invalid: \(urlString)")
    }
    return .image(url: url, description: description)
  }

  /// Sample figures for the stock card, not real market data. Each reply gets
  /// a new random trading day, so that each card shows different content.
  private static func makeStockQuote() -> ChatWidget.StockQuote {
    func cents(_ value: Double) -> Double {
      (value * 100).rounded() / 100
    }
    let previousClose = Double.random(in: 490...520)
    var price = previousClose + Double.random(in: -3...3)
    let intradayPrices = (0..<30).map { _ in
      price += Double.random(in: -1.8...1.9)
      return cents(price)
    }
    return ChatWidget.StockQuote(
      symbol: "MSFT",
      companyName: "Microsoft Corporation",
      previousClose: cents(previousClose),
      intradayPrices: intradayPrices,
      volume: Int.random(in: 14_000_000...26_000_000),
      // About 7.43 billion shares and $13.70 of earnings per share.
      marketCap: price * 7.43e9,
      priceEarningsRatio: (price / 13.7 * 10).rounded() / 10
    )
  }
}
