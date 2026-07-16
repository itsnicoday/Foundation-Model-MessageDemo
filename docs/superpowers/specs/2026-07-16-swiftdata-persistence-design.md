# SwiftData 메시지 영속화 설계 (Phase 3 - 1)

> 작성일: 2026-07-16

## 1. 배경 / 문제

현재 `ChatSession`/`Message`는 순수 인메모리 struct다. 앱을 종료하면 모든 채팅과
메시지가 사라진다 (`docs/PLAN.md` Phase 3 항목 1). Phase 3 항목 0(`ChatViewModelStore`
뷰모델 캐싱)으로 "앱이 켜져 있는 동안" 스트리밍/컨텍스트가 끊기지 않는 문제는
해소했지만, 앱을 완전히 재시작하면 여전히 아무것도 남지 않는다.

이번 작업은 **화면에 보이는 대화 내역(메시지 텍스트)** 을 디스크에 저장해
재시작 후에도 복원되게 하는 것까지만 다룬다. `LanguageModelSession`이 내부적으로
갖고 있는 모델 컨텍스트(대화 기억) 자체를 복원하는 것은 `Transcript` 저장/복원이
필요한 별개 작업이며, Phase 3 항목 2로 이미 분리되어 있다 — 이번 작업 이후에도
"재시작하면 화면엔 이전 대화가 보이지만, 모델은 그 대화를 기억하지 못한다"는
제약이 남는다. 이는 버그가 아니라 다음 항목으로 넘기는 의도된 범위다.

## 2. 목표

- 채팅 목록과 각 채팅의 메시지를 SwiftData로 영속화
- 앱 재시작 후 채팅 목록(생성 순서)과 메시지(전송 순서)가 그대로 복원
- 채팅 삭제가 영속 저장소에도 반영 (재시작해도 삭제된 채팅이 되살아나지 않음)
- 스트리밍 도중 토큰 단위로 디스크에 쓰지 않음 (성능 낭비 방지)
- 기존 값 타입(`ChatSession`/`Message` struct) 기반 UI/뷰모델 코드를 최대한 건드리지 않음

## 3. 아키텍처

### 3.1 새 파일

- `Models/ChatSessionEntity.swift`, `Models/MessageEntity.swift` — SwiftData `@Model`
  클래스. 영속 전용이며 UI/뷰모델 레이어는 이 타입을 직접 다루지 않는다.
- `Services/ChatPersistenceService.swift` — `ModelContext`를 감싸는 얇은 레포지토리.
  struct ↔ entity 변환은 이 서비스 내부에만 존재한다. 공개 API:
  ```swift
  @MainActor
  final class ChatPersistenceService {
      init(modelContext: ModelContext)

      func loadAllChats() -> [ChatSession]
      func createChat(_ chat: ChatSession)
      func deleteChat(id: ChatSession.ID)
      func appendMessage(_ message: Message, toChatID: ChatSession.ID)
  }
  ```

### 3.2 기존 파일 변경

- **`Models/ChatSession.swift`**: `let id = UUID()` → `let id: UUID`,
  `init(id: UUID = UUID(), title: String, messages: [Message])`. 새 채팅은 기존처럼
  자동 생성 id를 쓰고, 영속 로드 시에는 entity의 id를 그대로 넘겨받는다.
- **`Models/Message.swift`**: 동일한 이유로 `init(id: UUID = UUID(), isUser: Bool, text: String)`.
- **`Stores/ChatViewModelStore.swift`**:
  - `init(modelContext: ModelContext)`로 변경. 내부에서 `ChatPersistenceService`를
    생성하고, `loadAllChats()`로 `order`/`viewModels` 캐시를 채운다.
  - `createChat(title:)`: 새 `ChatSession` 생성 → `persistence.createChat(_:)` 호출
    → 캐시에 등록.
  - `deleteChat(at:)`: 기존처럼 캐시에서 제거 + 각 id에 대해 `persistence.deleteChat(id:)` 호출.
  - `ChatDetailViewModel` 생성 시 동일한 `persistence` 인스턴스를 주입.
- **`ViewModels/ChatDetailViewModel.swift`**:
  - `init(chat:persistence:)`로 변경, `private let persistence: ChatPersistenceService` 보관.
  - `sendMessage()`: 사용자 메시지를 `chat.messages`에 append한 직후
    `persistence.appendMessage(userMessage, toChatID: chat.id)` 호출.
  - 스트리밍 루프가 정상 종료되거나 에러로 빠지는 시점(어시스턴트 메시지 텍스트가
    더 이상 바뀌지 않는 시점)에 딱 한 번 `persistence.appendMessage(finalAssistantMessage, toChatID: chat.id)`
    호출. 루프 도중 텍스트가 갱신될 때마다 저장하지 않는다.
- **`Foundation_Model_MessageDemoApp.swift`**: `ModelContainer(for: ChatSessionEntity.self, MessageEntity.self)`를
  생성하고 `ChatViewModelStore(modelContext: container.mainContext)`로 넘긴다. 컨테이너
  생성이 실패하면(§5) 인메모리 컨테이너로 폴백한다.
- **프리뷰들** (`ContentView`, `ChatDetailView`, `SidebarView`의 `#Preview`): 실제
  디스크에 데이터가 남지 않도록 `ModelConfiguration(isStoredInMemoryOnly: true)`로 만든
  인메모리 컨테이너/컨텍스트를 사용.

## 4. 데이터 스키마

```swift
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

- 채팅 목록 순서, 채팅 내 메시지 순서 모두 `createdAt` 오름차순으로 복원한다.
  지금도 두 목록 모두 append-only라 "생성 시각순 정렬"이 "생성(전송)된 순서"와 동일하다.
- `ChatSessionEntity` 삭제 시 `deleteRule: .cascade`로 소속 `MessageEntity`도 함께 삭제된다.

## 5. 에러 처리 / 엣지 케이스

- **`ModelContainer` 생성 실패**: 앱 시작 시 크래시하지 않고 `ModelConfiguration(isStoredInMemoryOnly: true)`
  컨테이너로 폴백한다. 영속은 안 되지만 앱은 기존처럼 동작한다 (모델 사용 불가 시
  안내 메시지로 넘어가는 기존 기조와 동일하게, 영속 불가도 기능 정지가 아니라 성능 저하로 처리).
- **`context.save()` 실패**: 콘솔 로그만 남기고 UI에는 노출하지 않는다. 메시지는 이미
  메모리상 화면에 반영된 상태이므로 저장 실패가 곧 기능 실패는 아니다 (best-effort 영속,
  재시도 큐 등은 범위 밖).
- **스트리밍 중 채팅 삭제**: `deleteChat`이 캐시와 entity를 지워도, 이미 실행 중인
  `Task`는 끝까지 실행된 뒤 `appendMessage(toChatID:)`를 호출한다. 서비스가 해당 id의
  `ChatSessionEntity`를 못 찾으면(이미 삭제됨) 조용히 no-op한다 — 크래시 없이 무시.
  (이 시나리오 자체는 Phase 3 항목 0에서 이미 "크래시 없음"으로 검증됨.)
- **최초 실행(저장된 entity 없음)**: `loadAllChats()`가 빈 배열을 반환하고, 기존
  "Empty" 상태와 동일하게 동작한다.

## 6. 범위 밖 (Out of Scope)

- `LanguageModelSession`/`Transcript` 복원 (Phase 3 항목 2) — 이번 작업 이후에도
  재시작 시 화면 텍스트는 복원되지만 모델의 대화 기억은 복원되지 않는다.
- 롤링 요약/컨텍스트 압축 (Phase 3 항목 3)
- 채팅 제목 자동 생성
- 마이그레이션 전략 (기존 영속 데이터가 없는 첫 도입이라 스키마 마이그레이션 이슈 없음)

## 7. 수동 테스트 계획

시뮬레이터가 아닌 **실기기**에서 검증한다 (Apple Intelligence 지원 기기 필요, 기존과 동일).

1. 채팅 생성 → 메시지 전송 → 응답 완료까지 대기 → 앱을 완전히 종료 후 재실행 →
   채팅/메시지가 그대로 복원되는지 확인
2. 채팅 삭제 후 앱 재시작 → 삭제된 채팅이 다시 나타나지 않는지 확인
3. 스트리밍 중 채팅 삭제 → 크래시 없는지 확인 (기존 검증 항목 회귀 확인)
4. 여러 채팅을 생성한 뒤 재시작 → 사이드바 순서가 생성 순서와 동일하게 복원되는지 확인
