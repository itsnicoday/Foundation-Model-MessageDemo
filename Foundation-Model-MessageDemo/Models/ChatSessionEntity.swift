//
//  ChatSessionEntity.swift
//  Foundation-Model-MessageDemo
//

import Foundation
import SwiftData

@Model
final class ChatSessionEntity {
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \MessageEntity.chat)
    var messages: [MessageEntity] = []

    init(id: UUID, title: String, createdAt: Date = .now) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
    }
}
