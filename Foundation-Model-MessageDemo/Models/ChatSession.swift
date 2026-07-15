//
//  ChatSession.swift
//  Foundation-Model-MessageDemo
//
//  Created by 김호중 on 7/9/26.
//

import Foundation

struct ChatSession: Identifiable, Hashable {
    let id = UUID()
    var title: String
    var messages: [Message]

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: ChatSession, rhs: ChatSession) -> Bool {
        lhs.id == rhs.id
    }

    var lastMessagePreview: String {
        messages.last?.text ?? "New Chat"
    }
}
