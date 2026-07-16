//
//  Message.swift
//  Foundation-Model-MessageDemo
//
//  Created by 김호중 on 10/16/25.
//

import Foundation

struct Message: Identifiable, Hashable, Sendable {
    let id: UUID
    let isUser: Bool
    var text: String

    init(id: UUID = UUID(), isUser: Bool, text: String) {
        self.id = id
        self.isUser = isUser
        self.text = text
    }
}

// 뭐야??
