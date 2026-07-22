# Transcript 저장/복원 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 어시스턴트 응답이 한 번이라도 완료된 채팅은, 앱을 재시작해도 모델(`LanguageModelSession`)이 이전 대화 맥락을 그대로 이어서 답하게 한다.

**Architecture:** `ChatSessionEntity`에 `transcriptData: Data?` 필드를 추가하고, `ChatPersistenceService`가 `FoundationModels.Transcript`(Codable)를 이 필드로 인코딩/디코딩한다. `ChatModelService`는 저장된 transcript가 있으면 `LanguageModelSession(transcript:)`로, 없으면 기존처럼 기본 instructions로 세션을 만든다. `ChatDetailViewModel`은 어시스턴트 메시지를 저장하는 기존 체크포인트(응답 완료/에러 직후)에 transcript도 함께 저장한다.

**Tech Stack:** SwiftUI, SwiftData, FoundationModels, Swift 6.0, iOS 26.0.

## Global Constraints

- 배포 타겟 iOS 26.0, Swift 6.0, Universal(iPhone + iPad) — 기존과 동일, 변경 없음.
- 빌드 확인은 다음 명령으로 한다 (이 머신은 `xcode-select`가 CommandLineTools를 가리켜서 `DEVELOPER_DIR` 프리픽스가 필요하고, iPhone 16 시뮬레이터가 없어 iPhone 17을 사용한다):
  ```bash
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Foundation-Model-MessageDemo.xcodeproj -scheme Foundation-Model-MessageDemo -destination 'platform=iOS Simulator,name=iPhone 17' build
  ```
- 커밋된 테스트 타겟/스킴이 없어 `xcodebuild test`는 사용할 수 없다 — 빌드 성공 + (최종 태스크의) 실기기 수동 검증으로 대체한다.
- `Transcript` 복원/저장 동작은 시뮬레이터가 아니라 **실기기**(Apple Intelligence 지원 기기)에서 사용자가 직접 검증한다.
- `main` 브랜치에서 직접 진행한다 (기존 서브프로젝트들과 동일).
- 커밋 메시지는 `commit-with-approval` 스킬의 컨벤션(`type: 제목`, 소문자 type, 50자 이내 제목)을 따른다.

---

## File Structure

- Modify: `Foundation-Model-MessageDemo/Models/ChatSessionEntity.swift` — `transcriptData: Data?` 필드 추가
- Modify: `Foundation-Model-MessageDemo/Services/ChatModelService.swift` — 저장된 transcript로 세션 복원, 현재 transcript 노출
- Modify: `Foundation-Model-MessageDemo/Services/ChatPersistenceService.swift` — transcript 로드/저장 메서드 추가
- Modify: `Foundation-Model-MessageDemo/ViewModels/ChatDetailViewModel.swift` — transcript 로드 주입 + 체크포인트 저장 호출

---

## Task 1: 데이터 모델 + 서비스 계층 (transcript 필드, ChatModelService, ChatPersistenceService)

**Files:**
- Modify: `Foundation-Model-MessageDemo/Models/ChatSessionEntity.swift`
- Modify: `Foundation-Model-MessageDemo/Services/ChatModelService.swift`
- Modify: `Foundation-Model-MessageDemo/Services/ChatPersistenceService.swift`

**Interfaces:**
- Produces: `ChatModelService.init(transcript: Transcript? = nil)`, `ChatModelService.currentTranscript: Transcript?`, `ChatPersistenceService.loadTranscript(forChatID: ChatSession.ID) -> Transcript?`, `ChatPersistenceService.saveTranscript(_ transcript: Transcript?, forChatID: ChatSession.ID)`.
- Consumes: 없음. `ChatModelService()`(인자 없는 기존 호출부)는 기본값 `nil` 덕분에 변경 없이 계속 컴파일된다 — 이 태스크만으로는 기존 앱 동작이 바뀌지 않는다.

- [ ] **Step 1: `ChatSessionEntity`에 `transcriptData` 필드 추가**

`Foundation-Model-MessageDemo/Models/ChatSessionEntity.swift` 전체를 다음으로 교체:

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
    var transcriptData: Data?

    @Relationship(deleteRule: .cascade, inverse: \MessageEntity.chat)
    var messages: [MessageEntity] = []

    init(id: UUID, title: String, createdAt: Date = .now) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
    }
}
```

`transcriptData`는 `init`에 넣지 않는다 — 옵셔널 stored property라 자동으로 `nil`로 시작하고, 기존에 저장된 채팅들도 SwiftData 라이트웨이트 마이그레이션으로 이 필드가 `nil`인 채 그대로 로드된다.

- [ ] **Step 2: `ChatModelService`가 transcript를 복원/노출하도록 변경**

`Foundation-Model-MessageDemo/Services/ChatModelService.swift` 전체를 다음으로 교체:

```swift
//
//  ChatModelService.swift
//  Foundation-Model-MessageDemo
//
//  Created by 김호중 on 7/9/26.
//

import Foundation
import FoundationModels

/// LanguageModelSession(온디바이스 모델)을 감싸는 서비스 계층.
/// 채팅 하나당 인스턴스 하나를 사용해 대화 컨텍스트를 유지한다.
@MainActor
final class ChatModelService {

    private var session: LanguageModelSession?
    private let initialTranscript: Transcript?

    init(transcript: Transcript? = nil) {
        self.initialTranscript = transcript
    }

    /// 모델 사용 불가 사유. 사용 가능하면 nil.
    var unavailableReason: String? {
        switch SystemLanguageModel.default.availability {
        case .available:
            return nil
        case .unavailable(.deviceNotEligible):
            return "이 기기는 Apple Intelligence를 지원하지 않아요."
        case .unavailable(.appleIntelligenceNotEnabled):
            return "설정에서 Apple Intelligence를 켜주세요."
        case .unavailable(.modelNotReady):
            return "모델을 준비 중이에요. 잠시 후 다시 시도해주세요."
        case .unavailable:
            return "지금은 모델을 사용할 수 없어요."
        }
    }

    /// 세션이 한 번이라도 만들어졌으면 현재 대화 맥락. 모델을 아직 호출한 적 없으면 nil.
    var currentTranscript: Transcript? { session?.transcript }

    /// 응답을 조각 단위로 스트리밍한다. 각 요소는 "지금까지 생성된 전체 텍스트"(누적 스냅샷)이다.
    func streamResponse(to prompt: String) -> AsyncThrowingStream<String, Error> {
        let session = activeSession()

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await partial in session.streamResponse(to: prompt) {
                        continuation.yield(partial.content)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func activeSession() -> LanguageModelSession {
        if let session {
            return session
        }
        let session = initialTranscript.map { LanguageModelSession(transcript: $0) }
            ?? LanguageModelSession(
                instructions: "당신은 친절한 어시스턴트입니다. 한국어로 간결하게 답하세요."
            )
        self.session = session
        return session
    }
}
```

- [ ] **Step 3: `ChatPersistenceService`에 transcript 로드/저장 메서드 추가**

`Foundation-Model-MessageDemo/Services/ChatPersistenceService.swift` 전체를 다음으로 교체:

```swift
//
//  ChatPersistenceService.swift
//  Foundation-Model-MessageDemo
//

import Foundation
import SwiftData
import FoundationModels

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

    func loadTranscript(forChatID chatID: ChatSession.ID) -> Transcript? {
        guard let entity = fetchEntity(id: chatID), let data = entity.transcriptData else { return nil }
        return try? JSONDecoder().decode(Transcript.self, from: data)
    }

    func saveTranscript(_ transcript: Transcript?, forChatID chatID: ChatSession.ID) {
        guard let transcript, let entity = fetchEntity(id: chatID) else { return }
        entity.transcriptData = try? JSONEncoder().encode(transcript)
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

- [ ] **Step 4: 빌드 확인**

Run:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Foundation-Model-MessageDemo.xcodeproj -scheme Foundation-Model-MessageDemo -destination 'platform=iOS Simulator,name=iPhone 17' build
```
Expected: `** BUILD SUCCEEDED **`. (이 시점엔 아직 아무도 새 파라미터/메서드를 호출하지 않으므로, 기존 앱 동작은 변화가 없어야 한다.)

- [ ] **Step 5: 커밋**

```bash
git add Foundation-Model-MessageDemo/Models/ChatSessionEntity.swift Foundation-Model-MessageDemo/Services/ChatModelService.swift Foundation-Model-MessageDemo/Services/ChatPersistenceService.swift
git commit -m "feat: ChatModelService/PersistenceService에 Transcript 지원 추가"
```

---

## Task 2: ChatDetailViewModel 연결 + 실기기 검증

**Files:**
- Modify: `Foundation-Model-MessageDemo/ViewModels/ChatDetailViewModel.swift`

**Interfaces:**
- Consumes: Task 1의 `ChatModelService.init(transcript:)`, `ChatModelService.currentTranscript`, `ChatPersistenceService.loadTranscript(forChatID:)`, `ChatPersistenceService.saveTranscript(_:forChatID:)`.
- Produces: 없음 (앱의 최종 동작만 바뀐다).

- [ ] **Step 1: `ChatDetailViewModel`이 transcript를 로드하고 체크포인트마다 저장하도록 변경**

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

    private let service: ChatModelService
    private let persistence: ChatPersistenceService

    init(chat: ChatSession, persistence: ChatPersistenceService) {
        self.chat = chat
        self.persistence = persistence
        self.service = ChatModelService(transcript: persistence.loadTranscript(forChatID: chat.id))
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
                    persistence.saveTranscript(service.currentTranscript, forChatID: chat.id)
                }
            } catch {
                isLoading = false
                let errorText = "응답 생성에 실패했어요: \(error.localizedDescription)"
                if let index = assistantIndex {
                    chat.messages[index].text = errorText
                    persistence.appendMessage(chat.messages[index], toChatID: chat.id)
                    persistence.saveTranscript(service.currentTranscript, forChatID: chat.id)
                } else {
                    let errorMessage = Message(isUser: false, text: errorText)
                    chat.messages.append(errorMessage)
                    persistence.appendMessage(errorMessage, toChatID: chat.id)
                    persistence.saveTranscript(service.currentTranscript, forChatID: chat.id)
                }
            }
        }
    }
}
```

어시스턴트 메시지를 저장하는 3곳(스트리밍 성공 완료, catch 블록 안 `assistantIndex` 있는 경우, catch 블록 안 `assistantIndex` 없는 경우) 모두 바로 다음 줄에 `saveTranscript` 호출을 추가했다. `unavailableReason` 조기 리턴 분기는 세션 자체가 생성되지 않아 `currentTranscript`가 항상 `nil`이므로 건드리지 않는다.

- [ ] **Step 2: 빌드 확인**

Run:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Foundation-Model-MessageDemo.xcodeproj -scheme Foundation-Model-MessageDemo -destination 'platform=iOS Simulator,name=iPhone 17' build
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: 커밋**

```bash
git add Foundation-Model-MessageDemo/ViewModels/ChatDetailViewModel.swift
git commit -m "feat: ChatDetailViewModel을 Transcript 복원에 연결"
```

- [ ] **Step 4: 실기기 수동 검증 (사용자 수행)**

다음을 실기기(Apple Intelligence 지원 기기)에 설치해 확인 — 시뮬레이터가 아님:
1. 채팅 생성 → 메시지 전송 → 응답 완료까지 대기 → 앱을 완전히 종료 후 재실행 → 같은 채팅에 맥락이 필요한 후속 질문(예: "방금 내가 뭐라고 물어봤지?")을 보내 모델이 이전 대화를 실제로 기억하는지 확인
2. 메시지를 한 번도 보내지 않은 새 채팅으로 재시작 → 기존과 동일하게 정상 동작하는지(회귀 없음) 확인
3. 응답 도중 에러가 난 채팅도 transcript가 저장되어 재시작 후 이어지는지 확인
4. Task 1/2 적용 전에 이미 저장돼 있던(즉 `transcriptData`가 없는) 기존 채팅을 열어도 크래시 없이 정상 로드되는지 확인

이 결과를 사용자에게 확인받은 뒤 `docs/PLAN.md`의 Phase 3 항목 2 체크박스를 완료로 표시한다.
