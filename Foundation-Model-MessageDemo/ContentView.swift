//
//  ContentView.swift
//  Foundation-Model-MessageDemo
//
//  Created by 김호중 on 10/16/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(ChatViewModelStore.self) private var chatStore
    @State private var selectedChatID: ChatSession.ID?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(
                selectedChatID: $selectedChatID,
                chats: chatStore.chats,
                onCreateNewChat: createNewChat,
                onDeleteChat: chatStore.deleteChat
            )
        } detail: {
            if let selectedChatID, chatStore.viewModel(for: selectedChatID) != nil {
                ChatDetailView(chatID: selectedChatID)
                    .id(selectedChatID)
            } else {
                Text("Select a conversation")
                    .foregroundColor(.secondary)
            }
        }
    }

    private func createNewChat() {
        let newChat = chatStore.createChat(title: "New Chat \(chatStore.chats.count + 1)")
        selectedChatID = newChat.id
    }
}

#Preview("With Chats") {
    let store = ChatViewModelStore(modelContext: ModelContainer.preview.mainContext)
    store.createChat(title: "SwiftUI 질문")
    store.createChat(title: "두 번째 채팅")
    return ContentView()
        .environment(store)
}

#Preview("Empty") {
    ContentView()
        .environment(ChatViewModelStore(modelContext: ModelContainer.preview.mainContext))
}
