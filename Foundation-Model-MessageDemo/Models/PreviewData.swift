//
//  PreviewData.swift
//  Foundation-Model-MessageDemo
//
//  Created by 김호중 on 7/9/26.
//

import Foundation

#if DEBUG
extension Message {
    static let sampleUser = Message(isUser: true, text: "SwiftUI에서 NavigationSplitView는 어떻게 써?")
    static let sampleAssistant = Message(isUser: false, text: "NavigationSplitView는 사이드바와 디테일 영역을 나눠주는 컨테이너예요. iPad에서는 두 컬럼으로, iPhone에서는 스택으로 표시됩니다.")

    static let sampleConversation: [Message] = [
        Message(isUser: true, text: "안녕! 오늘 뭐 도와줄 수 있어?"),
        Message(isUser: false, text: "안녕하세요! iOS 개발 관련해서 무엇이든 물어보세요."),
        Message(isUser: true, text: "SwiftUI에서 NavigationSplitView는 어떻게 써?"),
        Message(isUser: false, text: "NavigationSplitView는 사이드바와 디테일 영역을 나눠주는 컨테이너예요. iPad에서는 두 컬럼으로, iPhone에서는 스택으로 표시됩니다."),
        Message(isUser: true, text: "오 좋네. 예제 코드도 보여줄 수 있어?")
    ]
}

extension ChatSession {
    static let sample = ChatSession(title: "SwiftUI 질문", messages: Message.sampleConversation)

    static let samples: [ChatSession] = [
        sample,
        ChatSession(title: "FoundationModels 공부", messages: [
            Message(isUser: true, text: "LanguageModelSession이 뭐야?"),
            Message(isUser: false, text: "Apple의 온디바이스 LLM과 대화하기 위한 세션 객체입니다.")
        ]),
        ChatSession(title: "New Chat 3", messages: [])
    ]
}
#endif
