//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import Combine
import SwiftStreamingMarkdown

/// A Markdown reply's content, observed by its cell. A streaming reply
/// updates this object instead of reconfiguring its cell through the
/// snapshot.
@MainActor
final class AssistantReplyViewModel: ObservableObject {
  @Published private(set) var document: RenderableDocument

  init(document: RenderableDocument) {
    self.document = document
  }

  func setDocument(_ newDocument: RenderableDocument) {
    // Only publish real changes, so that the cell doesn't update for nothing.
    if document != newDocument {
      document = newDocument
    }
  }
}
