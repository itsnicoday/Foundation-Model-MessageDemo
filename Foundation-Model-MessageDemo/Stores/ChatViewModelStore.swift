//
//  ChatViewModelStore.swift
//  Foundation-Model-MessageDemo
//

import SwiftUI
import SwiftData
import Observation

@MainActor
@Observable
final class ChatViewModelStore {

    private var order: [ChatSession.ID] = []
    private var viewModels: [ChatSession.ID: ChatDetailViewModel] = [:]
    private let persistence: ChatPersistenceService

    var chats: [ChatSession] {
        order.compactMap { viewModels[$0]?.chat }
    }

    init(modelContext: ModelContext) {
        let persistence = ChatPersistenceService(modelContext: modelContext)
        self.persistence = persistence
        for chat in persistence.loadAllChats() {
            order.append(chat.id)
            viewModels[chat.id] = ChatDetailViewModel(chat: chat, persistence: persistence)
        }
    }

    func viewModel(for id: ChatSession.ID) -> ChatDetailViewModel? {
        viewModels[id]
    }

    @discardableResult
    func createChat(title: String) -> ChatSession {
        let chat = ChatSession(title: title, messages: [])
        persistence.createChat(chat)
        order.append(chat.id)
        viewModels[chat.id] = ChatDetailViewModel(chat: chat, persistence: persistence)
        return chat
    }

    func deleteChat(at offsets: IndexSet) {
        let idsToRemove = offsets.map { order[$0] }
        order.remove(atOffsets: offsets)
        idsToRemove.forEach {
            viewModels[$0] = nil
            persistence.deleteChat(id: $0)
        }
    }
}
