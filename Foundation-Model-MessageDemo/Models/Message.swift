//
//  Message.swift
//  Foundation-Model-MessageDemo
//
//  Created by 김호중 on 10/16/25.
//

import Foundation

struct Message: Identifiable, Hashable, Sendable {
    let id: UUID = UUID()
    let isUser: Bool
    let text: String
}
