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

#Preview {
    NavigationStack {
        SidebarView(
            selectedChat: .constant(ChatSession.samples.first),
            chats: ChatSession.samples,
            onCreateNewChat: {},
            onDeleteChat: { _ in }
        )
    }
}
