# 채팅 뷰모델 스토어 (ChatViewModelStore) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 채팅을 전환해도 스트리밍/입력 상태가 끊기지 않도록, `ChatSession` 목록과 `ChatDetailViewModel` 캐시를 하나의 `ChatViewModelStore`로 통합한다.

**Architecture:** `ChatViewModelStore`(`@Observable`, App 진입점에서 생성해 `.environment(_:)`로 주입)가 채팅 id별 `ChatDetailViewModel`을 계속 살려두고, 세션 목록(`chats`)은 이 캐시로부터 파생되는 계산 프로퍼티로 만든다. `ChatDetailView`는 `chatID`만 받는 얇은 래퍼로 바뀌어 `body`에서 store를 조회하고, 기존 화면 로직은 이름만 바뀐 `ChatDetailContentView`가 그대로 담당한다. `ContentView`는 선택된 `chatID`만 로컬 상태로 들고, 나머지는 store에 위임한다.

**Tech Stack:** SwiftUI, Swift 6 Observation 프레임워크(`@Observable`, `@Environment`), 서드파티 의존성 없음.

## Global Constraints

- 배포 타겟 iOS 26.0, Swift 6.0 (기존 프로젝트 설정, 변경하지 않음)
- 이 프로젝트에는 테스트 타겟/`.xcscheme`가 커밋되어 있지 않아 `xcodebuild test`를 실행할 수 없다 — 각 태스크의 검증은 `xcodebuild build` 성공 + iOS 시뮬레이터에서의 수동 확인으로 대체한다.
- 빌드 명령 (이 세션에서 검증된 형태 — `xcode-select`가 CommandLineTools를 가리키고 있어 `DEVELOPER_DIR` 오버라이드가 필요함):
  ```bash
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
    -project Foundation-Model-MessageDemo.xcodeproj \
    -scheme Foundation-Model-MessageDemo \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    build
  ```
- Xcode 16 파일시스템 동기화 그룹(`PBXFileSystemSynchronizedRootGroup`)을 사용 중이므로 새 `.swift` 파일은 `project.pbxproj` 수정 없이 자동으로 타겟에 포함된다.
- 커밋 전 항상 `commit-with-approval` 스킬 절차(초안 표시 → 승인 대기 → 커밋)를 따른다.
- 스펙 문서: `docs/superpowers/specs/2026-07-16-chat-viewmodel-store-design.md` — 이 계획의 모든 태스크는 그 문서의 아키텍처를 그대로 구현한다.

---

## File Structure

- **Create:** `Foundation-Model-MessageDemo/Stores/ChatViewModelStore.swift` — 채팅 id별 `ChatDetailViewModel` 캐시 + 파생된 세션 목록. 앱의 유일한 채팅 데이터 원본.
- **Modify:** `Foundation-Model-MessageDemo/Foundation_Model_MessageDemoApp.swift` — store를 생성해 `.environment(_:)`로 주입.
- **Modify:** `Foundation-Model-MessageDemo/Views/ChatDetailView.swift` — `ChatDetailView`(얇은 래퍼)와 `ChatDetailContentView`(기존 화면 로직) 두 구조체로 분리.
- **Modify:** `Foundation-Model-MessageDemo/ContentView.swift` — `chats`/`selectedChat` 소유를 제거하고 store를 읽는 형태로 전환.
- **Modify:** `Foundation-Model-MessageDemo/Views/SidebarView.swift` — 선택 상태 타입을 `ChatSession?` → `ChatSession.ID?`로 변경.

---

### Task 1: `ChatViewModelStore` 생성

**Files:**
- Create: `Foundation-Model-MessageDemo/Stores/ChatViewModelStore.swift`

**Interfaces:**
- Consumes: `ChatSession`(`Models/ChatSession.swift`), `ChatDetailViewModel`(`ViewModels/ChatDetailViewModel.swift`) — 둘 다 기존 파일, 변경 없음.
- Produces: `ChatViewModelStore` 클래스 — `var chats: [ChatSession] { get }`, `func viewModel(for id: ChatSession.ID) -> ChatDetailViewModel?`, `func createChat(title: String) -> ChatSession`, `func deleteChat(at offsets: IndexSet)`. Task 2·3에서 이 시그니처를 그대로 사용한다.

- [ ] **Step 1: 파일 작성**

```swift
//
//  ChatViewModelStore.swift
//  Foundation-Model-MessageDemo
//

import Foundation
import Observation

@MainActor
@Observable
final class ChatViewModelStore {

    private var order: [ChatSession.ID] = []
    private var viewModels: [ChatSession.ID: ChatDetailViewModel] = [:]

    var chats: [ChatSession] {
        order.compactMap { viewModels[$0]?.chat }
    }

    func viewModel(for id: ChatSession.ID) -> ChatDetailViewModel? {
        viewModels[id]
    }

    @discardableResult
    func createChat(title: String) -> ChatSession {
        let viewModel = ChatDetailViewModel(chat: ChatSession(title: title, messages: []))
        order.append(viewModel.chat.id)
        viewModels[viewModel.chat.id] = viewModel
        return viewModel.chat
    }

    func deleteChat(at offsets: IndexSet) {
        let idsToRemove = offsets.map { order[$0] }
        order.remove(atOffsets: offsets)
        idsToRemove.forEach { viewModels[$0] = nil }
    }
}
```

- [ ] **Step 2: 빌드로 컴파일 확인**

Run:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project Foundation-Model-MessageDemo.xcodeproj \
  -scheme Foundation-Model-MessageDemo \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  build
```
Expected: `** BUILD SUCCEEDED **`. (이 시점에는 아직 아무도 `ChatViewModelStore`를 사용하지 않으므로, 새 파일이 기존 타겟과 충돌 없이 컴파일되는지만 확인하는 단계.)

- [ ] **Step 3: 커밋**

`commit-with-approval` 절차대로 초안을 먼저 보여주고 승인 후 커밋:
```bash
git add Foundation-Model-MessageDemo/Stores/ChatViewModelStore.swift
git commit -m "$(cat <<'EOF'
ChatViewModelStore 추가

채팅 id별 ChatDetailViewModel 캐시와, 그로부터 파생되는 세션 목록을 하나로 묶는 저장소를 도입한다. 아직 어디서도 사용하지 않음 (다음 커밋에서 연결).

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: App 진입점에 store 주입

**Files:**
- Modify: `Foundation-Model-MessageDemo/Foundation_Model_MessageDemoApp.swift`

**Interfaces:**
- Consumes: `ChatViewModelStore()` (Task 1에서 정의).
- Produces: 환경에 주입된 `ChatViewModelStore` 인스턴스 — Task 3에서 `@Environment(ChatViewModelStore.self)`로 읽는다.

- [ ] **Step 1: 파일 전체 교체**

`Foundation-Model-MessageDemo/Foundation_Model_MessageDemoApp.swift`:

```swift
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
```

- [ ] **Step 2: 빌드로 컴파일 확인**

Run: (Task 1과 동일한 `xcodebuild` 명령)
Expected: `** BUILD SUCCEEDED **`. (`ContentView`가 아직 environment 값을 읽지 않으므로 경고 없이 그대로 통과해야 함.)

- [ ] **Step 3: 커밋**

```bash
git add Foundation-Model-MessageDemo/Foundation_Model_MessageDemoApp.swift
git commit -m "$(cat <<'EOF'
App 진입점에서 ChatViewModelStore를 environment로 주입

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```
(커밋 전 `commit-with-approval` 절차에 따라 초안을 먼저 보여주고 승인받는다.)

---

### Task 3: `ChatDetailView` 분리 + `ContentView`/`SidebarView`를 store 기반으로 전환

이 태스크는 세 파일을 함께 바꾼다 — Swift는 타겟 전체를 한 번에 컴파일하므로, `ChatDetailView`의 시그니처만 바꾸고 호출부(`ContentView`)를 그대로 두면 빌드가 깨진다. 세 변경이 합쳐져야 비로소 다시 빌드되는 하나의 단위다.

**Files:**
- Modify: `Foundation-Model-MessageDemo/Views/ChatDetailView.swift` (전체 교체)
- Modify: `Foundation-Model-MessageDemo/ContentView.swift` (전체 교체)
- Modify: `Foundation-Model-MessageDemo/Views/SidebarView.swift` (전체 교체)

**Interfaces:**
- Consumes: `ChatViewModelStore.chats`, `.viewModel(for:)`, `.createChat(title:)`, `.deleteChat(at:)` (Task 1), `.environment(chatStore)`로 주입된 인스턴스 (Task 2).
- Produces: `ChatDetailView(chatID: ChatSession.ID)` — 이후 다른 화면에서 재사용한다면 이 시그니처를 따른다. `ChatDetailContentView(viewModel: ChatDetailViewModel)`.

- [ ] **Step 1: `ChatDetailView.swift` 전체 교체**

```swift
//
//  ChatDetailView.swift
//  Foundation-Model-MessageDemo
//
//  Created by 김호중 on 7/9/26.
//

import SwiftUI

struct ChatDetailView: View {
    @Environment(ChatViewModelStore.self) private var store
    let chatID: ChatSession.ID

    var body: some View {
        if let viewModel = store.viewModel(for: chatID) {
            ChatDetailContentView(viewModel: viewModel)
        }
    }
}

struct ChatDetailContentView: View {

    @State private var viewModel: ChatDetailViewModel

    init(viewModel: ChatDetailViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.chat.messages) { message in
                            MessageView(message: message, isLoading: false)
                                .id(message.id)
                        }

                        if viewModel.isLoading {
                            MessageView(
                                message: Message(isUser: false, text: ""),
                                isLoading: true
                            )
                            .id("loading")
                        }
                    }
                    .padding(.horizontal, 8)
                }
                .onChange(of: viewModel.chat.messages.count) {
                    scrollToBottom(proxy: proxy)
                }
                .onChange(of: viewModel.chat.messages.last?.text) {
                    scrollToBottom(proxy: proxy)
                }
                .onChange(of: viewModel.isLoading) {
                    scrollToBottom(proxy: proxy)
                }
            }

            inputBar
        } //: VStack
        .navigationTitle(viewModel.chat.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Input Bar
    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("Message", text: $viewModel.inputText)
                .textFieldStyle(.plain)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .foregroundStyle(.gray.opacity(0.15))
                )

            Button(action: viewModel.sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title)
            }
            .disabled(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } //: HStack
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        let target: AnyHashable? = viewModel.isLoading ? "loading" : viewModel.chat.messages.last?.id
        guard let target else { return }
        withAnimation {
            proxy.scrollTo(target, anchor: .bottom)
        }
    }
}

#Preview {
    NavigationStack {
        ChatDetailContentView(viewModel: ChatDetailViewModel(chat: .sample))
    }
}
```

(기존 `onUpdate: (ChatSession) -> Void` 파라미터와 `.onChange(of: viewModel.chat) { onUpdate(viewModel.chat) }` 블록은 제거됨 — `viewModel.chat`이 곧 store가 들고 있는 원본이라 더 이상 필요 없음.)

- [ ] **Step 2: `SidebarView.swift` 전체 교체**

```swift
//
//  SidebarView.swift
//  Foundation-Model-MessageDemo
//
//  Created by Hogent on 2026-02-15.
//

import SwiftUI

struct SidebarView: View {
    @Binding var selectedChatID: ChatSession.ID?
    let chats: [ChatSession]
    var onCreateNewChat: () -> Void
    var onDeleteChat: (IndexSet) -> Void

    var body: some View {
        List(selection: $selectedChatID) {
            Section(header: Text("Chats")) {
                ForEach(chats) { chat in
                    NavigationLink(value: chat.id) {
                        VStack(alignment: .leading) {
                            Text(chat.title)
                                .font(.headline)
                            if let lastMsg = chat.messages.last?.text {
                                Text(lastMsg)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .lineLimit(1)
                            } else {
                                Text("New Chat")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .onDelete(perform: onDeleteChat)
            }
        }
        .listStyle(SidebarListStyle())
        .navigationTitle("Messages")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: onCreateNewChat) {
                    Label("New Chat", systemImage: "square.and.pencil")
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        SidebarView(
            selectedChatID: .constant(ChatSession.samples.first?.id),
            chats: ChatSession.samples,
            onCreateNewChat: {},
            onDeleteChat: { _ in }
        )
    }
}
```

- [ ] **Step 3: `ContentView.swift` 전체 교체**

```swift
//
//  ContentView.swift
//  Foundation-Model-MessageDemo
//
//  Created by 김호중 on 10/16/25.
//

import SwiftUI

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

#Preview("With Chats") {
    let store = ChatViewModelStore()
    store.createChat(title: "SwiftUI 질문")
    store.createChat(title: "두 번째 채팅")
    return ContentView()
        .environment(store)
}

#Preview("Empty") {
    ContentView()
        .environment(ChatViewModelStore())
}
```

(참고: `#Preview("With Chats")`는 기존처럼 `ChatSession.samples`의 대화 내용까지 미리보기에 담지는 못한다 — `createChat`은 항상 빈 메시지로 채팅을 만들기 때문. 프리뷰 전용의 사소한 손실이며 실기능에는 영향 없음.)

- [ ] **Step 4: 빌드로 컴파일 확인**

Run: (Task 1과 동일한 `xcodebuild` 명령)
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: 시뮬레이터에서 수동 검증**

Xcode에서 `Foundation-Model-MessageDemo` 스킴으로 iPhone 17 시뮬레이터 실행 후:
1. 채팅 A를 만들고 메시지를 보내 응답 스트리밍이 시작되는 도중 사이드바에서 채팅 B로 전환 → 완료 전에 다시 채팅 A로 돌아왔을 때 스트리밍이 끊기지 않고 이어지거나(또는 이미 완료돼 있는지) 확인. 이게 이번 작업 전체의 핵심 검증 포인트.
2. 스트리밍이 진행 중인 채팅을 사이드바에서 스와이프 삭제 → 크래시 없이 정상 동작하는지 확인.
3. 채팅 생성/삭제/전환, 사이드바의 마지막 메시지 미리보기, 빈 상태("Select a conversation") 문구 등 기존 동작이 전부 그대로인지 확인.

Expected: 세 항목 모두 통과.

- [ ] **Step 6: 커밋**

```bash
git add Foundation-Model-MessageDemo/Views/ChatDetailView.swift \
        Foundation-Model-MessageDemo/Views/SidebarView.swift \
        Foundation-Model-MessageDemo/ContentView.swift
git commit -m "$(cat <<'EOF'
채팅 전환 시 스트리밍/입력 상태가 끊기지 않도록 ChatViewModelStore 기반으로 전환

ChatDetailView를 얇은 래퍼(ChatDetailView)와 기존 화면 로직(ChatDetailContentView)으로 분리하고, ContentView/SidebarView가 더 이상 ChatSession 배열을 직접 소유하지 않고 ChatViewModelStore를 단일 진실 공급원으로 사용하도록 바꿨다. 채팅 id별 ChatDetailViewModel이 store에 계속 캐시되어, 다른 채팅으로 이동했다가 돌아와도 진행 중이던 스트리밍이 유지된다.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```
(커밋 전 `commit-with-approval` 절차에 따라 초안을 먼저 보여주고 승인받는다.)

---

## 이 계획 이후 (범위 밖)

- `docs/PLAN.md` Phase 3의 "0. 뷰모델 캐싱 계층" 항목을 완료로 표시 — Task 3 완료 후 별도로 진행.
- SwiftData 영속화, `Transcript` 복원, 롤링 요약은 각각 별도 스펙/계획으로 다룬다 (스펙 문서의 "범위 밖" 참고).
