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

    init(chat: ChatSession) {
        self.chat = chat
    }

    var unavailableReason: String? { service.unavailableReason }

    func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        chat.messages.append(Message(isUser: true, text: text))
        inputText = ""

        if let reason = service.unavailableReason {
            chat.messages.append(Message(isUser: false, text: reason))
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
            } catch {
                isLoading = false
                let errorText = "응답 생성에 실패했어요: \(error.localizedDescription)"
                if let index = assistantIndex {
                    chat.messages[index].text = errorText
                } else {
                    chat.messages.append(Message(isUser: false, text: errorText))
                }
            }
        }
    }
}
