# SwiftData 메시지 영속화 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 채팅 목록과 메시지를 SwiftData로 영속화해 앱 재시작 후에도 대화 내역이 복원되게 한다.

**Architecture:** `ChatSessionEntity`/`MessageEntity` (`@Model`)를 새로 만들고, `ChatPersistenceService`가 이 entity들과 기존 `ChatSession`/`Message` struct 사이 변환을 전담한다. `ChatViewModelStore`와 `ChatDetailViewModel`은 이 서비스를 통해서만 영속 계층과 통신하며, 스트리밍 도중이 아니라 메시지가 확정되는 체크포인트(사용자 메시지 전송 직후, 어시스턴트 응답 완료/에러 직후)에만 저장을 호출한다.

**Tech Stack:** SwiftUI, SwiftData, Swift 6.0, iOS 26.0.

## Global Constraints

- 배포 타겟 iOS 26.0, Swift 6.0, Universal(iPhone + iPad) — 기존과 동일, 변경 없음.
- 빌드 확인은 다음 명령으로 한다 (이 머신은 `xcode-select`가 CommandLineTools를 가리켜서 `DEVELOPER_DIR` 프리픽스가 필요하고, iPhone 16 시뮬레이터가 없어 iPhone 17을 사용한다):
  ```bash
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Foundation-Model-MessageDemo.xcodeproj -scheme Foundation-Model-MessageDemo -destination 'platform=iOS Simulator,name=iPhone 17' build
  ```
- 커밋된 테스트 타겟/스킴이 없어 `xcodebuild test`는 사용할 수 없다 — 빌드 성공 + (최종 태스크의) 실기기 수동 검증으로 대체한다.
- 실제 영속화 동작(재시작 후 복원 등)은 시뮬레이터가 아니라 **실기기**에서 사용자가 직접 검증한다 (사용자 지정).
- `main` 브랜치에서 직접 진행한다 (사용자가 이전 서브프로젝트에서 이미 확정한 방식, 이번에도 동일하게 적용).

---

## File Structure

- Create: `Foundation-Model-MessageDemo/Models/ChatSessionEntity.swift` — SwiftData `@Model`, 채팅 세션 영속 표현
- Create: `Foundation-Model-MessageDemo/Models/MessageEntity.swift` — SwiftData `@Model`, 메시지 영속 표현
- Create: `Foundation-Model-MessageDemo/Services/ChatPersistenceService.swift` — entity ↔ struct 변환 및 CRUD 전담
- Modify: `Foundation-Model-MessageDemo/Models/ChatSession.swift` — `id`를 생성자 파라미터로 받도록 변경
- Modify: `Foundation-Model-MessageDemo/Models/Message.swift` — 동일하게 `id`를 생성자 파라미터로 받도록 변경
- Modify: `Foundation-Model-MessageDemo/ViewModels/ChatDetailViewModel.swift` — persistence 주입 및 체크포인트 저장 호출
- Modify: `Foundation-Model-MessageDemo/Stores/ChatViewModelStore.swift` — `modelContext` 주입, 로드/생성/삭제 시 persistence 연동
- Modify: `Foundation-Model-MessageDemo/Foundation_Model_MessageDemoApp.swift` — `ModelContainer` 생성 및 주입
- Modify: `Foundation-Model-MessageDemo/Models/PreviewData.swift` — 프리뷰용 인메모리 `ModelContainer` 헬퍼 추가
- Modify: `Foundation-Model-MessageDemo/ContentView.swift` — 프리뷰가 인메모리 컨테이너로 store 생성하도록 변경
- Modify: `Foundation-Model-MessageDemo/Views/ChatDetailView.swift` — 프리뷰가 persistence를 주입하도록 변경

---

## Task 1: SwiftData 데이터 계층 (entity + persistence service + id 파라미터화)

**Files:**
- Create: `Foundation-Model-MessageDemo/Models/ChatSessionEntity.swift`
- Create: `Foundation-Model-MessageDemo/Models/MessageEntity.swift`
- Create: `Foundation-Model-MessageDemo/Services/ChatPersistenceService.swift`
- Modify: `Foundation-Model-MessageDemo/Models/ChatSession.swift`
- Modify: `Foundation-Model-MessageDemo/Models/Message.swift`

**Interfaces:**
- Produces: `ChatSessionEntity(id: UUID, title: String, createdAt: Date = .now)`, `MessageEntity(id: UUID, isUser: Bool, text: String, createdAt: Date = .now)`, `ChatPersistenceService(modelContext: ModelContext)` with `loadAllChats() -> [ChatSession]`, `createChat(_ chat: ChatSession)`, `deleteChat(id: ChatSession.ID)`, `appendMessage(_ message: Message, toChatID: ChatSession.ID)`. `ChatSession.init(id: UUID = UUID(), title: String, messages: [Message])`, `Message.init(id: UUID = UUID(), isUser: Bool, text: String)`.
- Consumes: 없음 (이 태스크는 새 데이터 계층만 추가하며, 기존 호출부는 기본값 있는 `id` 덕분에 변경 없이 계속 컴파일된다).

- [ ] **Step 1: `ChatSession`에 `id` 파라미터 추가**

`Foundation-Model-MessageDemo/Models/ChatSession.swift` 전체를 다음으로 교체:

```swift
//
//  ChatSession.swift
//  Foundation-Model-MessageDemo
//
//  Created by 김호중 on 7/9/26.
//

import Foundation

struct ChatSession: Identifiable, Hashable {
    let id: UUID
    var title: String
    var messages: [Message]

    init(id: UUID = UUID(), title: String, messages: [Message]) {
        self.id = id
        self.title = title
        self.messages = messages
    }

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
```

- [ ] **Step 2: `Message`에 `id` 파라미터 추가**

`Foundation-Model-MessageDemo/Models/Message.swift`의 struct 정의를 다음으로 교체 (파일 끝의 `// 뭐야??` 주석 줄은 그대로 둔다):

```swift
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
```

- [ ] **Step 3: `ChatSessionEntity` 생성**

`Foundation-Model-MessageDemo/Models/ChatSessionEntity.swift` 새로 작성:

```swift
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
```

- [ ] **Step 4: `MessageEntity` 생성**

`Foundation-Model-MessageDemo/Models/MessageEntity.swift` 새로 작성:

```swift
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
```

- [ ] **Step 5: `ChatPersistenceService` 생성**

`Foundation-Model-MessageDemo/Services/ChatPersistenceService.swift` 새로 작성:

```swift
//
//  ChatPersistenceService.swift
//  Foundation-Model-MessageDemo
//

import Foundation
import SwiftData

@MainActor
final class ChatPersistenceService {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func loadAllChats() -> [ChatSession] {
        let descriptor = FetchDescriptor<ChatSessionEntity>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        let entities = (try? modelContext.fetch(descriptor)) ?? []
        return entities.map { entity in
            let messages = entity.messages
                .sorted { $0.createdAt < $1.createdAt }
                .map { Message(id: $0.id, isUser: $0.isUser, text: $0.text) }
            return ChatSession(id: entity.id, title: entity.title, messages: messages)
        }
    }

    func createChat(_ chat: ChatSession) {
        let entity = ChatSessionEntity(id: chat.id, title: chat.title)
        modelContext.insert(entity)
        saveIfNeeded()
    }

    func deleteChat(id: ChatSession.ID) {
        guard let entity = fetchEntity(id: id) else { return }
        modelContext.delete(entity)
        saveIfNeeded()
    }

    func appendMessage(_ message: Message, toChatID chatID: ChatSession.ID) {
        guard let chatEntity = fetchEntity(id: chatID) else { return }
        let messageEntity = MessageEntity(id: message.id, isUser: message.isUser, text: message.text)
        messageEntity.chat = chatEntity
        chatEntity.messages.append(messageEntity)
        saveIfNeeded()
    }

    private func fetchEntity(id: ChatSession.ID) -> ChatSessionEntity? {
        var descriptor = FetchDescriptor<ChatSessionEntity>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    private func saveIfNeeded() {
        guard modelContext.hasChanges else { return }
        do {
            try modelContext.save()
        } catch {
            print("ChatPersistenceService save failed: \(error)")
        }
    }
}
```

- [ ] **Step 6: 빌드 확인**

Run:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Foundation-Model-MessageDemo.xcodeproj -scheme Foundation-Model-MessageDemo -destination 'platform=iOS Simulator,name=iPhone 17' build
```
Expected: `** BUILD SUCCEEDED **`. (이 시점엔 아직 아무도 새 서비스를 호출하지 않으므로, 기존 앱 동작은 변화가 없어야 한다.)

- [ ] **Step 7: 커밋**

```bash
git add Foundation-Model-MessageDemo/Models/ChatSessionEntity.swift Foundation-Model-MessageDemo/Models/MessageEntity.swift Foundation-Model-MessageDemo/Services/ChatPersistenceService.swift Foundation-Model-MessageDemo/Models/ChatSession.swift Foundation-Model-MessageDemo/Models/Message.swift
git commit -m "SwiftData 영속 계층(ChatSessionEntity/MessageEntity/ChatPersistenceService) 추가"
```

---

## Task 2: 통합 (Store/ViewModel 연동, App 진입점, 프리뷰)

**Files:**
- Modify: `Foundation-Model-MessageDemo/ViewModels/ChatDetailViewModel.swift`
- Modify: `Foundation-Model-MessageDemo/Stores/ChatViewModelStore.swift`
- Modify: `Foundation-Model-MessageDemo/Foundation_Model_MessageDemoApp.swift`
- Modify: `Foundation-Model-MessageDemo/Models/PreviewData.swift`
- Modify: `Foundation-Model-MessageDemo/ContentView.swift`
- Modify: `Foundation-Model-MessageDemo/Views/ChatDetailView.swift`

**Interfaces:**
- Consumes: Task 1의 `ChatPersistenceService`, `ChatSessionEntity`, `MessageEntity`, `ChatSession.init(id:title:messages:)`, `Message.init(id:isUser:text:)`.
- Produces: `ChatDetailViewModel.init(chat:persistence:)`, `ChatViewModelStore.init(modelContext:)`, `ModelContainer.preview` (프리뷰 전용 인메모리 컨테이너).

이 태스크의 모든 변경은 서로 강하게 결합되어 있다 (Store가 새 `ChatDetailViewModel` 초기화 시그니처를 호출하고, App이 새 `ChatViewModelStore` 초기화 시그니처를 호출한다). Swift는 타겟 전체를 한 번에 컴파일하므로 이 파일들을 나눠서 각각 독립적으로 빌드 검증하는 것은 의미가 없다 — 한 번에 적용하고 마지막에 함께 빌드 검증한다.

- [ ] **Step 1: `ChatDetailViewModel`에 persistence 주입 및 체크포인트 저장 추가**

`Foundation-Model-MessageDemo/ViewModels/ChatDetailViewModel.swift` 전체를 다음으로 교체:

```swift
//
//  ChatDetailViewModel.swift
//  Foundation-Model-MessageDemo
//
//  Created by 김호중 on 7/16/26.
//

import Foundation
import Observation

@MainActor
@Observable
final class ChatDetailViewModel {

    var chat: ChatSession
    var inputText: String = ""
    var isLoading: Bool = false

    private let service = ChatModelService()
    private let persistence: ChatPersistenceService

    init(chat: ChatSession, persistence: ChatPersistenceService) {
        self.chat = chat
        self.persistence = persistence
    }

    var unavailableReason: String? { service.unavailableReason }

    func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let userMessage = Message(isUser: true, text: text)
        chat.messages.append(userMessage)
        persistence.appendMessage(userMessage, toChatID: chat.id)
        inputText = ""

        if let reason = service.unavailableReason {
            let errorMessage = Message(isUser: false, text: reason)
            chat.messages.append(errorMessage)
            persistence.appendMessage(errorMessage, toChatID: chat.id)
            return
        }

        isLoading = true
        Task {
            var assistantIndex: Int?
            do {
                for try await partial in service.streamResponse(to: text) {
                    if let index = assistantIndex {
                        chat.messages[index].text = partial
                    } else {
                        isLoading = false
                        assistantIndex = chat.messages.count
                        chat.messages.append(Message(isUser: false, text: partial))
                    }
                }
                if let index = assistantIndex {
                    persistence.appendMessage(chat.messages[index], toChatID: chat.id)
                }
            } catch {
                isLoading = false
                let errorText = "응답 생성에 실패했어요: \(error.localizedDescription)"
                if let index = assistantIndex {
                    chat.messages[index].text = errorText
                    persistence.appendMessage(chat.messages[index], toChatID: chat.id)
                } else {
                    let errorMessage = Message(isUser: false, text: errorText)
                    chat.messages.append(errorMessage)
                    persistence.appendMessage(errorMessage, toChatID: chat.id)
                }
            }
        }
    }
}
```

- [ ] **Step 2: `ChatViewModelStore`가 persistence를 통해 로드/생성/삭제하도록 변경**

`Foundation-Model-MessageDemo/Stores/ChatViewModelStore.swift` 전체를 다음으로 교체:

```swift
//
//  ChatViewModelStore.swift
//  Foundation-Model-MessageDemo
//

import SwiftUI
import SwiftData
import Observation

@MainActor
@Observable
final class ChatViewModelStore {

    private var order: [ChatSession.ID] = []
    private var viewModels: [ChatSession.ID: ChatDetailViewModel] = [:]
    private let persistence: ChatPersistenceService

    var chats: [ChatSession] {
        order.compactMap { viewModels[$0]?.chat }
    }

    init(modelContext: ModelContext) {
        let persistence = ChatPersistenceService(modelContext: modelContext)
        self.persistence = persistence
        for chat in persistence.loadAllChats() {
            order.append(chat.id)
            viewModels[chat.id] = ChatDetailViewModel(chat: chat, persistence: persistence)
        }
    }

    func viewModel(for id: ChatSession.ID) -> ChatDetailViewModel? {
        viewModels[id]
    }

    @discardableResult
    func createChat(title: String) -> ChatSession {
        let chat = ChatSession(title: title, messages: [])
        persistence.createChat(chat)
        order.append(chat.id)
        viewModels[chat.id] = ChatDetailViewModel(chat: chat, persistence: persistence)
        return chat
    }

    func deleteChat(at offsets: IndexSet) {
        let idsToRemove = offsets.map { order[$0] }
        order.remove(atOffsets: offsets)
        idsToRemove.forEach {
            viewModels[$0] = nil
            persistence.deleteChat(id: $0)
        }
    }
}
```

- [ ] **Step 3: App 진입점에서 `ModelContainer` 생성 및 주입**

`Foundation-Model-MessageDemo/Foundation_Model_MessageDemoApp.swift` 전체를 다음으로 교체:

```swift
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
```

- [ ] **Step 4: 프리뷰용 인메모리 컨테이너 헬퍼 추가**

`Foundation-Model-MessageDemo/Models/PreviewData.swift`에서 최상단 `import Foundation` 다음 줄에 `import SwiftData`를 추가하고, `#if DEBUG` 블록 안 `extension Message { ... }` 앞에 다음 extension을 추가:

```swift
extension ModelContainer {
    static var preview: ModelContainer {
        let schema = Schema([ChatSessionEntity.self, MessageEntity.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: configuration)
    }
}
```

파일 최종 형태:

```swift
//
//  PreviewData.swift
//  Foundation-Model-MessageDemo
//
//  Created by 김호중 on 7/9/26.
//

import Foundation
import SwiftData

#if DEBUG
extension ModelContainer {
    static var preview: ModelContainer {
        let schema = Schema([ChatSessionEntity.self, MessageEntity.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: configuration)
    }
}

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
```

- [ ] **Step 5: `ContentView` 프리뷰가 인메모리 컨테이너로 store를 만들도록 변경**

`Foundation-Model-MessageDemo/ContentView.swift`에서 최상단에 `import SwiftData` 추가하고, 파일 하단의 두 `#Preview` 블록을 다음으로 교체:

```swift
#Preview("With Chats") {
    let store = ChatViewModelStore(modelContext: ModelContainer.preview.mainContext)
    store.createChat(title: "SwiftUI 질문")
    store.createChat(title: "두 번째 채팅")
    return ContentView()
        .environment(store)
}

#Preview("Empty") {
    ContentView()
        .environment(ChatViewModelStore(modelContext: ModelContainer.preview.mainContext))
}
```

- [ ] **Step 6: `ChatDetailView` 프리뷰가 persistence를 주입하도록 변경**

`Foundation-Model-MessageDemo/Views/ChatDetailView.swift`에서 최상단에 `import SwiftData` 추가하고, 파일 하단 `#Preview` 블록을 다음으로 교체:

```swift
#Preview {
    let persistence = ChatPersistenceService(modelContext: ModelContainer.preview.mainContext)
    return NavigationStack {
        ChatDetailContentView(viewModel: ChatDetailViewModel(chat: .sample, persistence: persistence))
    }
}
```

- [ ] **Step 7: 빌드 확인**

Run:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Foundation-Model-MessageDemo.xcodeproj -scheme Foundation-Model-MessageDemo -destination 'platform=iOS Simulator,name=iPhone 17' build
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 8: 커밋**

```bash
git add Foundation-Model-MessageDemo/ViewModels/ChatDetailViewModel.swift Foundation-Model-MessageDemo/Stores/ChatViewModelStore.swift Foundation-Model-MessageDemo/Foundation_Model_MessageDemoApp.swift Foundation-Model-MessageDemo/Models/PreviewData.swift Foundation-Model-MessageDemo/ContentView.swift Foundation-Model-MessageDemo/Views/ChatDetailView.swift
git commit -m "ChatViewModelStore/ChatDetailViewModel을 SwiftData 영속 계층에 연결"
```

- [ ] **Step 9: 실기기 수동 검증 (사용자 수행)**

다음을 실기기(Apple Intelligence 지원 기기)에 설치해 확인 — 시뮬레이터가 아님:
1. 채팅 생성 → 메시지 전송 → 응답 완료까지 대기 → 앱을 완전히 종료 후 재실행 → 채팅/메시지가 그대로 복원되는지
2. 채팅 삭제 후 앱 재시작 → 삭제된 채팅이 다시 나타나지 않는지
3. 스트리밍 중 채팅 삭제 → 크래시 없는지 (Phase 3 항목 0에서 검증된 기존 동작 회귀 확인)
4. 여러 채팅 생성 후 재시작 → 사이드바 순서가 생성 순서와 동일하게 복원되는지

이 결과를 사용자에게 확인받은 뒤 `docs/PLAN.md`의 Phase 3 항목 1 체크박스를 완료로 표시한다.
