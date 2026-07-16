//
//  Foundation_Model_MessageDemoApp.swift
//  Foundation-Model-MessageDemo
//
//  Created by 김호중 on 10/16/25.
//

import SwiftUI

@main
struct Foundation_Model_MessageDemoApp: App {
    @State private var chatStore = ChatViewModelStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(chatStore)
        }
    }
}
