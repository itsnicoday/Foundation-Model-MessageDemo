//
//  ChatDetailViewModel.swift
//  Foundation-Model-MessageDemo
//
//  Created by 김호중 on 7/16/26.
//

import Foundation
import Observation

@MainActor
@Observable
final class ChatDetailViewModel {

    var chat: ChatSession
    var inputText: String = ""
    var isLoading: Bool = false

    private let service = ChatModelService()
    private let persistence: ChatPersistenceService

    init(chat: ChatSession, persistence: ChatPersistenceService) {
        self.chat = chat
        self.persistence = persistence
    }

    var unavailableReason: String? { service.unavailableReason }

    func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let userMessage = Message(isUser: true, text: text)
        chat.messages.append(userMessage)
        persistence.appendMessage(userMessage, toChatID: chat.id)
        inputText = ""

        if let reason = service.unavailableReason {
            let errorMessage = Message(isUser: false, text: reason)
            chat.messages.append(errorMessage)
            persistence.appendMessage(errorMessage, toChatID: chat.id)
            return
        }

        isLoading = true
        Task {
            var assistantIndex: Int?
            do {
                for try await partial in service.streamResponse(to: text) {
                    if let index = assistantIndex {
                        chat.messages[index].text = partial
                    } else {
                        isLoading = false
                        assistantIndex = chat.messages.count
                        chat.messages.append(Message(isUser: false, text: partial))
                    }
                }
                if let index = assistantIndex {
                    persistence.appendMessage(chat.messages[index], toChatID: chat.id)
                }
            } catch {
                isLoading = false
                let errorText = "응답 생성에 실패했어요: \(error.localizedDescription)"
                if let index = assistantIndex {
                    chat.messages[index].text = errorText
                    persistence.appendMessage(chat.messages[index], toChatID: chat.id)
                } else {
                    let errorMessage = Message(isUser: false, text: errorText)
                    chat.messages.append(errorMessage)
                    persistence.appendMessage(errorMessage, toChatID: chat.id)
                }
            }
        }
    }
}
