//
//  ChatViewModelStore.swift
//  Foundation-Model-MessageDemo
//

import SwiftUI
import Observation

@MainActor
@Observable
final class ChatViewModelStore {

    private var order: [ChatSession.ID] = []
    private var viewModels: [ChatSession.ID: ChatDetailViewModel] = [:]

    var chats: [ChatSession] {
        order.compactMap { viewModels[$0]?.chat }
    }

    func viewModel(for id: ChatSession.ID) -> ChatDetailViewModel? {
        viewModels[id]
    }

    @discardableResult
    func createChat(title: String) -> ChatSession {
        let viewModel = ChatDetailViewModel(chat: ChatSession(title: title, messages: []))
        order.append(viewModel.chat.id)
        viewModels[viewModel.chat.id] = viewModel
        return viewModel.chat
    }

    func deleteChat(at offsets: IndexSet) {
        let idsToRemove = offsets.map { order[$0] }
        order.remove(atOffsets: offsets)
        idsToRemove.forEach { viewModels[$0] = nil }
    }
}
