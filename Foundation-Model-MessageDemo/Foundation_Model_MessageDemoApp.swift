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
    private let container: ModelContainer

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
        self.container = container
        _chatStore = State(initialValue: ChatViewModelStore(modelContext: container.mainContext))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(chatStore)
        }
        // SwiftUI Scene에 컨테이너를 등록해야 함 — 안 하면 실기기/시뮬레이터에서
        // "Illegal attempt to insert a model in to a different model context" 크래시 발생
        .modelContainer(container)
    }
}
