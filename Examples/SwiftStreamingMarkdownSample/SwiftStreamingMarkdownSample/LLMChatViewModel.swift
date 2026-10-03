//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import Foundation
import SwiftStreamingMarkdown

/// Presentation state for `LLMChatViewController`: the chat transcript and
/// draft input.
/// All send/streaming logic lives in `LLMChatInteractor`; this type only holds
/// state and exposes main-actor mutations the interactor drives.
@MainActor
final class LLMChatViewModel: ObservableObject {
  @Published private(set) var messages: [ChatMessage] = []
  @Published var draft = ""

  var canSend: Bool {
    !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  /// Return the trimmed draft and clear the input, or `nil` if it is blank.
  func consumeDraft() -> String? {
    let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else { return nil }
    draft = ""
    return text
  }

  func appendUserMessage(_ text: String) {
    messages.append(ChatMessage(content: .user(text)))
  }

  /// Append an assistant message that shows a thinking indicator until its
  /// reply arrives, and return its id so that the reply can replace it.
  func appendThinkingMessage() -> UUID {
    let message = ChatMessage(content: .thinking)
    messages.append(message)
    return message.id
  }

  /// Append an assistant message and return its id so streaming updates can
  /// target the same message as its content grows.
  func appendAssistantMessage(_ document: RenderableDocument) -> UUID {
    let message = ChatMessage(content: .assistant(document))
    messages.append(message)
    return message.id
  }

  func updateAssistantMessage(id: UUID, document: RenderableDocument) {
    guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
    messages[index].content = .assistant(document)
  }

  func updateAssistantMessage(id: UUID, widget: ChatWidget) {
    guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
    messages[index].content = .widget(widget)
  }
}

struct ChatMessage: Identifiable {
  enum Content: Equatable {
    case user(String)
    /// An assistant reply that hasn't arrived yet.
    case thinking
    case assistant(RenderableDocument)
    /// An assistant reply shown with a native view instead of Markdown.
    case widget(ChatWidget)
  }

  let id = UUID()
  var content: Content
}
