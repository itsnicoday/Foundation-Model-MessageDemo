//
//  MessageEntity.swift
//  Foundation-Model-MessageDemo
//

import Foundation
import SwiftData

@Model
final class MessageEntity {
    var id: UUID
    var isUser: Bool
    var text: String
    var createdAt: Date
    var chat: ChatSessionEntity?

    init(id: UUID, isUser: Bool, text: String, createdAt: Date = .now) {
        self.id = id
        self.isUser = isUser
        self.text = text
        self.createdAt = createdAt
    }
}
