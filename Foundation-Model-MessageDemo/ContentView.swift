//
//  ContentView.swift
//  Foundation-Model-MessageDemo
//
//  Created by 김호중 on 10/16/25.
//

import SwiftUI

struct ContentView: View {
    @State private var chats: [ChatSession] = []
    @State private var selectedChat: ChatSession?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(
                selectedChat: $selectedChat,
                chats: chats,
                onCreateNewChat: createNewChat,
                onDeleteChat: deleteChat
            )
        } detail: {
            if let chat = selectedChat {
                // TODO: ChatDetailView(chat: chat)
                VStack {
                    Text(chat.title)
                        .font(.largeTitle)
                    
                    ScrollView {
                        ForEach(chat.messages) { message in
                            MessageView(message: message, isLoading: false)
                        }
                    }
                }
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

#Preview {
    ContentView()
}
