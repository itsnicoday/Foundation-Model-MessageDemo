//
//  Foundation_Model_MessageDemoApp.swift
//  Foundation-Model-MessageDemo
//
//  Created by 김호중 on 10/16/25.
//

import SwiftUI
import SwiftData

@main
struct Foundation_Model_MessageDemoApp: App {
    @State private var chatStore: ChatViewModelStore

    init() {
        let schema = Schema([ChatSessionEntity.self, MessageEntity.self])
        let container: ModelContainer
        do {
            container = try ModelContainer(for: schema)
        } catch {
            print("ModelContainer 생성 실패, 인메모리로 대체: \(error)")
            container = try! ModelContainer(
                for: schema,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
        }
        _chatStore = State(initialValue: ChatViewModelStore(modelContext: container.mainContext))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(chatStore)
        }
    }
}
