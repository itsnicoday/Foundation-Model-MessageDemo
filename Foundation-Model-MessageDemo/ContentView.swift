//
//  ContentView.swift
//  Foundation-Model-MessageDemo
//
//  Created by 김호중 on 10/16/25.
//

import SwiftUI

struct ContentView: View {
    @State private var chats: [ChatSession]
    @State private var selectedChat: ChatSession?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    init(chats: [ChatSession] = []) {
        _chats = State(initialValue: chats)
        _selectedChat = State(initialValue: chats.first)
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(
                selectedChat: $selectedChat,
                chats: chats,
                onCreateNewChat: createNewChat,
                onDeleteChat: deleteChat
            )
        } detail: {
            if let selectedChat, let index = chats.firstIndex(where: { $0.id == selectedChat.id }) {
                ChatDetailView(chat: chats[index]) { updated in
                    if let index = chats.firstIndex(where: { $0.id == updated.id }) {
                        chats[index] = updated
                    }
                }
                .id(selectedChat.id)
            } else {
                Text("Select a conversation")
                    .foregroundColor(.secondary)
            }
        }
    }

    private func createNewChat() {
        let newChat = ChatSession(title: "New Chat \(chats.count + 1)", messages: [])
        chats.append(newChat)
        selectedChat = newChat
    }

    private func deleteChat(at offsets: IndexSet) {
        chats.remove(atOffsets: offsets)
        if chats.isEmpty {
            selectedChat = nil
        }
    }
}

#Preview("With Chats") {
    ContentView(chats: ChatSession.samples)
}

#Preview("Empty") {
    ContentView()
}
