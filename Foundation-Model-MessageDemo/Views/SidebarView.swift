//
//  SidebarView.swift
//  Foundation-Model-MessageDemo
//
//  Created by Hogent on 2026-02-15.
//

import SwiftUI

struct SidebarView: View {
    @Binding var selectedChat: ChatSession?
    let chats: [ChatSession]
    var onCreateNewChat: () -> Void
    var onDeleteChat: (IndexSet) -> Void

    var body: some View {
        List(selection: $selectedChat) {
            Section(header: Text("Chats")) {
                ForEach(chats) { chat in
                    NavigationLink(value: chat) {
                        VStack(alignment: .leading) {
                            Text(chat.title)
                                .font(.headline)
                            if let lastMsg = chat.messages.last?.text {
                                Text(lastMsg)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .lineLimit(1)
                            } else {
                                Text("New Chat")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .onDelete(perform: onDeleteChat)
            }
        }
        .listStyle(SidebarListStyle())
        .navigationTitle("Messages")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: onCreateNewChat) {
                    Label("New Chat", systemImage: "square.and.pencil")
                }
            }
        }
    }
}

// MARK: - Dummy Model
// Hashable 구현 명시적으로 추가 (안전하게)
struct ChatSession: Identifiable, Hashable {
    let id = UUID()
    var title: String
    var messages: [Message]
    
    // Hashable 구현
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // Equatable 구현
    static func == (lhs: ChatSession, rhs: ChatSession) -> Bool {
        lhs.id == rhs.id
    }
    
    var lastMessagePreview: String {
        messages.last?.text ?? "New Chat"
    }
}
