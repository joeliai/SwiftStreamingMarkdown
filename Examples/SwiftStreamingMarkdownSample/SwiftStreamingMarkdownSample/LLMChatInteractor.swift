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

  /// Mock replies in the order they rotate. A long story and the native views
  /// come right after the introduction so that they are quick to reach.
  private static let mockResponses: [MockResponse] = [
    .markdown("""
    SwiftStreamingMarkdown is designed to render Markdown incrementally as an LLM response arrives. It supports headings, lists, tables, citations, code blocks, math, and more.

    You can learn more in the [project documentation](https://github.com/microsoft/SwiftStreamingMarkdown?citationMarker=9F742443&citationTitle=SwiftStreamingMarkdown&citationA11yValue=SwiftStreamingMarkdown%20GitHub%20repository&citationId=chat-doc-1&chatItemId=llm-chat).
    """),
    .markdown("""
    # The Keeper of Slow Letters

    ## I. The station at the edge of the map

    On the island of Vell, where the wind had opinions about everything, there was a telegraph station older than anyone who lived there. It sat on the last rock before the open sea: a squat stone building with one window, one stove, and one very patient woman named Mara Quill.

    The cable that connected Vell to the mainland had been laid by people who expected it to last a hundred years. It had lasted a hundred and twelve, and it was tired. Messages no longer arrived all at once. They arrived the way rain begins: a single word, then a pause long enough to wonder whether that was all, then another word, and another.

    Most people found this maddening. Mara found it restful. She kept a stack of cream-colored cards on her desk and wrote each word down as it came, in pencil, so that she could fix her mistakes. When a message was finished, she read it aloud once, folded the card in half, and carried it into town herself.

    > *"A slow letter is still a letter,"* her grandmother used to say. *"It just takes the scenic route."*

    ## II. Things on Mara's desk

    Over the years, the desk had collected a small museum of useful objects:

    1. A brass bell that rang whenever the line came alive.
    2. A tin of peppermints, mostly for visitors and partly for herself.
    3. A logbook of every message the station had ever carried, in eleven different handwritings.
    4. A photograph of the lighthouse on the far side of the island, which had been dark for as long as she could remember.

    She dusted the photograph every Sunday. She could not have told you why.

    ## III. The first word

    The storm arrived on a Tuesday in late November, and the message arrived with it.

    The bell rang just after midnight. Mara lit the lamp, sharpened her pencil, and waited. The line hummed. The needle trembled. And then, very slowly, the first word came through:

    **LOST.**

    She wrote it down and waited for the rest. Nothing came for a long time. The wind threw handfuls of rain against the window. The stove ticked as it cooled. Mara put another log on the fire and did not take her eyes off the needle.

    **IN.**

    **FOG.**

    Three words in nearly an hour. Somewhere out on the water, somebody was tapping out a message one careful letter at a time, and the old cable was carrying it as best it could.

    ## IV. Waiting

    By morning the whole town knew. People do not have much to talk about on Vell in November, so a message that took all night to arrive was the best news in years.

    They came up the hill in ones and twos. The baker brought bread. The schoolteacher brought her students, who had never seen the station and wanted to know why it smelled like pencil shavings. The harbor master brought a chart and spread it across the floor, weighing down the corners with Mara's peppermints.

    "If they're in the fog," he said, "they're somewhere out past the reef. Nobody goes past the reef in fog. Not on purpose."

    "Then they're not there on purpose," said Mara, and wrote down the next word:

    **NO.**

    **LIGHT.**

    The room went quiet. Everyone looked, without meaning to, at the photograph on the desk.

    ## V. What the fog said

    The rest of the message came through over the next few hours, one word at a time, while the town held its breath and the baker's bread went quietly stale. When it was finished, Mara read it aloud, the way she always did:

    > *Lost in fog. No light. Engine failing. Child aboard. Drifting south of the reef. Can anyone see us.*

    "Can anyone see us," the schoolteacher repeated softly. There was no question mark. The cable had never carried question marks; it only carried what people meant.

    The harbor master shook his head. "We can't send a boat out in this. We'd lose two crews instead of one."

    Mara looked at the photograph of the dark lighthouse for a long moment. Then she stood, took her coat from the hook, and put the brass bell in her pocket.

    "We don't need to find them," she said. "We need them to find us."

    ## VI. The light

    The lighthouse had been dark for thirty-one years. Its lamp was cracked, its gears were rusted, and its staircase had a hundred and forty steps, eleven of which were missing. Everyone who climbed it that afternoon remembered the count for the rest of their lives.

    They could not fix the great lamp, but the town had other lights. The baker brought every lantern from the bakery. The schoolteacher's students brought the candles from the school's winter play. The harbor master brought the signal flares he had been saving for an emergency, and admitted, a little sheepishly, that this was probably it.

    They set them all at the top of the tower, behind the old glass, and lit them one by one, the way the message had arrived: a single light, then a pause, then another, and another, until the top of the lighthouse glowed like a coal blown back to life.

    Then Mara went back down to the station, sat at her desk, and tapped out a reply on the old cable, one slow word at a time:

    **LOOK.**

    **NORTH.**

    **WE.**

    **SEE.**

    **YOU.**

    ## VII. Afterward

    The boat came in at dawn, limping through the last of the fog with its engine coughing and its crew waving at the light as if it were an old friend. There were four sailors aboard, and a girl of about nine who had kept the boat's log the whole way, one word at a time, because she had read somewhere that the person keeping the log is never allowed to be afraid.

    She gave Mara the logbook. Mara gave her a peppermint.

    The town never did fix the great lamp. But every year since, on the last Tuesday in November, the people of Vell climb the hundred and forty steps (all of them present now) and light one lantern each at the top of the tower. They light them slowly, one at a time, with a pause in between, so that anyone out on the water has time to notice.

    Mara still keeps the station. The cable is older than ever, and the messages arrive more slowly every year. She does not mind. She sharpens her pencil, waits for the bell, and writes each word down as it comes.

    *A slow letter is still a letter.* It just takes the scenic route.
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
