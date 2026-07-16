# 채팅 뷰모델 스토어 설계 (Phase 3 - 0. 뷰모델 캐싱 계층)

> 최종 수정: 2026-07-16

## 배경 / 문제

현재 `ContentView`는 채팅을 전환할 때마다 `ChatDetailView`에 `.id(selectedChat.id)`를 붙여 완전히 새로운 뷰/뷰모델 인스턴스를 만든다. 그 결과:

- 응답이 스트리밍되는 도중 다른 채팅으로 이동했다가 돌아오면 진행 상태가 사라진다.
- 입력창에 남아 있던 draft도 함께 사라진다.

또한 설계 논의 과정에서, 단순히 뷰모델을 캐싱만 하는 경우 `ContentView`가 "`chats: [ChatSession]` 배열"과 "뷰모델 캐시" 두 개의 별도 저장소를 양쪽 다 알고 손으로 동기화해야 하는 문제가 드러났다. 이는 이전에 사용자가 명시적으로 거부했던 "`ContentView`가 `ChatDetailViewModel`을 직접 다루는" 구조와 본질적으로 같은 종류의 결합이다.

## 목표

- 채팅을 전환해도 스트리밍/입력 상태가 끊기지 않도록 `ChatDetailViewModel`을 채팅 id별로 계속 살려둔다.
- `ChatSession` 목록과 뷰모델 캐시를 하나의 저장소로 통합해, 두 데이터가 서로 어긋날 여지 자체를 없앤다.
- `ContentView`는 "요청만 보내고 결과만 반영받는" 얇은 조율자로 남긴다 — 데이터 소유권이나 동기화 책임을 지지 않는다.

## 아키텍처

```
Foundation_Model_MessageDemoApp (@State chatStore) ──.environment(chatStore)──▶ ContentView
                                                                                     │ (선택 상태만 보유)
                                                                          ChatDetailView (얇은 래퍼)
                                                                          @Environment(ChatViewModelStore.self)
                                                                                     │ store.viewModel(for: chatID)
                                                                                     ▼
                                                                          ChatDetailContentView
                                                                          (기존 ChatDetailView 본문, .id(chatID))
```

### `Stores/ChatViewModelStore.swift` (신규)

`ChatSession` 목록 자체를 별도로 들고 있지 않고, 뷰모델 딕셔너리가 곧 세션 목록의 원본이 된다.

```swift
@MainActor @Observable
final class ChatViewModelStore {
    private var order: [ChatSession.ID] = []
    private var viewModels: [ChatSession.ID: ChatDetailViewModel] = [:]

    var chats: [ChatSession] { order.compactMap { viewModels[$0]?.chat } }

    func viewModel(for id: ChatSession.ID) -> ChatDetailViewModel? { viewModels[id] }

    @discardableResult
    func createChat(title: String) -> ChatSession {
        let vm = ChatDetailViewModel(chat: ChatSession(title: title, messages: []))
        order.append(vm.chat.id)
        viewModels[vm.chat.id] = vm
        return vm.chat
    }

    func deleteChat(at offsets: IndexSet) {
        let ids = offsets.map { order[$0] }
        order.remove(atOffsets: offsets)
        ids.forEach { viewModels[$0] = nil }
    }
}
```

### App 진입점 (`Foundation_Model_MessageDemoApp.swift`)

```swift
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
```

### `ChatDetailView.swift` — 얇은 래퍼로 분리

`@Environment`는 커스텀 `init()` 내부에서는 아직 주입되지 않으므로, `body`에서 조회해 실제 내용을 담은 뷰로 넘긴다.

```swift
struct ChatDetailView: View {
    @Environment(ChatViewModelStore.self) private var store
    let chatID: ChatSession.ID

    var body: some View {
        if let viewModel = store.viewModel(for: chatID) {
            ChatDetailContentView(viewModel: viewModel)
        }
    }
}
```

기존 `ChatDetailView`의 본문(메시지 리스트, 자동 스크롤, 입력 바 등)은 이름만 `ChatDetailContentView`로 바뀌고, 로직 변경 없이 그대로 옮겨간다. `init`은 `chat: ChatSession` 대신 `viewModel: ChatDetailViewModel`을 직접 받는다.

```swift
struct ChatDetailContentView: View {
    @State private var viewModel: ChatDetailViewModel

    init(viewModel: ChatDetailViewModel) {
        _viewModel = State(initialValue: viewModel)
    }
    // 이하 body는 기존 ChatDetailView와 동일 (onUpdate 관련 코드만 제거)
}
```

### `ContentView.swift`

```swift
struct ContentView: View {
    @Environment(ChatViewModelStore.self) private var chatStore
    @State private var selectedChatID: ChatSession.ID?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(
                selectedChatID: $selectedChatID,
                chats: chatStore.chats,
                onCreateNewChat: createNewChat,
                onDeleteChat: chatStore.deleteChat
            )
        } detail: {
            if let selectedChatID, chatStore.viewModel(for: selectedChatID) != nil {
                ChatDetailView(chatID: selectedChatID)
                    .id(selectedChatID)
            } else {
                Text("Select a conversation")
                    .foregroundColor(.secondary)
            }
        }
    }

    private func createNewChat() {
        let newChat = chatStore.createChat(title: "New Chat \(chatStore.chats.count + 1)")
        selectedChatID = newChat.id
    }
}
```

`SidebarView`는 지금처럼 `chats: [ChatSession]`을 파라미터로 받되, 값이 `chatStore.chats`에서 흘러온다는 점만 다르다 — 내부 코드는 변경 없음(단, 현재 `selectedChat: Binding<ChatSession?>`을 쓰던 부분은 `selectedChatID: Binding<ChatSession.ID?>`로 바뀌어야 하므로 `SidebarView`의 선택 관련 코드는 타입만 맞춰 손봄).

### `onUpdate` 클로저 제거

`ChatDetailViewModel.chat`이 곧 store가 들고 있는 원본이므로, 변경 사항을 부모에게 알리기 위한 `onUpdate: (ChatSession) -> Void` 콜백이 더 이상 필요 없다. `chatStore.chats`를 읽는 모든 뷰(사이드바 등)는 `@Observable` 추적을 통해 자동으로 최신 상태를 받는다.

## 데이터 흐름 요약

1. 사용자가 메시지를 보내면 `ChatDetailContentView`가 `viewModel.sendMessage()` 호출.
2. `ChatDetailViewModel`이 자신의 `chat.messages`를 갱신 — 이 인스턴스는 `ChatViewModelStore.viewModels[id]`에 저장된 것과 동일한 참조이므로 별도 전파 없이 즉시 store의 `chats`에도 반영됨.
3. 채팅 전환 시 `ContentView`가 `.id(selectedChatID)`로 새 `ChatDetailView`/`ChatDetailContentView`를 만들어도, `store.viewModel(for:)`가 같은 인스턴스를 다시 돌려주므로 스트리밍 중이던 `Task`와 상태가 그대로 유지됨.

## 에러 처리 / 엣지 케이스

- **선택된 채팅이 store에 없는 경우** (삭제 직후 등): `ContentView`가 `chatStore.viewModel(for: selectedChatID) != nil`을 확인해 없으면 "Select a conversation" 플레이스홀더로 폴백 — 기존 `chats.firstIndex(where:)` 체크와 동등한 안전장치.
- **스트리밍 중 채팅 삭제**: `sendMessage`의 `Task { }`가 암묵적으로 `self`를 강하게 캡처하므로, store에서 제거돼도 Task는 끝까지 실행된다. 아무도 관찰하지 않는 객체를 조용히 갱신하다 끝나는 것뿐이라 크래시나 누수로 이어지지 않는다 — 별도 취소 로직은 지금 단계에서 추가하지 않는다.
- **`createChat` 직후 선택**: `ContentView.createNewChat`이 `chatStore.createChat(title:)`이 반환한 `ChatSession.id`로 `selectedChatID`를 설정 — 기존 흐름과 동일.

## 테스트 방법 (수동)

1. `xcodebuild`로 빌드 성공 확인.
2. 채팅 A에서 응답 스트리밍 시작 → 완료 전에 채팅 B로 전환 → 다시 A로 돌아와서 스트리밍이 끊기지 않고 이어지는지(또는 이미 완료돼 있는지) 확인 — 이번 작업의 핵심 검증 포인트.
3. 스트리밍 중인 채팅을 사이드바에서 삭제 → 크래시 없이 정상 동작하는지 확인.
4. 채팅 생성/삭제/전환의 기존 동작(사이드바 목록, 빈 상태 문구)이 그대로인지 확인.

## 범위 밖 (Out of scope)

- 앱 재시작 후 영속화 (SwiftData) — Phase 3의 다음 하위 항목.
- 모델 컨텍스트(`Transcript`) 복원, 롤링 요약 — 그 다음 하위 항목들.
- 채팅 제목 자동 생성 — 별도 항목, 이번 작업과 무관.
