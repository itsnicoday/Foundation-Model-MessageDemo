# Transcript 저장/복원 설계 (Phase 3 - 2)

> 작성일: 2026-07-23

## 1. 배경 / 문제

Phase 3 항목 1(SwiftData 메시지 영속화)로 화면에 보이는 대화 내역(메시지 텍스트)은
앱 재시작 후에도 복원된다. 하지만 `LanguageModelSession`이 내부적으로 갖고 있는
모델 자체의 대화 기억(`Transcript`)은 여전히 복원되지 않는다 — 재시작하면 화면엔
이전 대화가 그대로 보이지만, 새 메시지를 보내면 모델은 그 대화를 전혀 모르는 채로
답한다.

당시 계획서에는 "`Transcript`의 Codable 여부·정확한 API는 베타라 Xcode에서
재확인 필요"라고 불확실성이 남아 있었다. 이번에 iOS 26.5 SDK의
`FoundationModels.swiftinterface`를 직접 확인해 다음을 검증했다:

- `Transcript`는 `Sendable`, `Equatable`, `RandomAccessCollection`, 그리고
  **`Codable`**을 준수한다.
- `LanguageModelSession(model:tools:transcript:)` 생성자로 저장된 transcript
  그대로 세션을 복원할 수 있다. `Transcript.Entry`에 `.instructions(...)` 케이스가
  있어 최초 instructions도 transcript 안에 이미 포함되므로 복원 시 별도로 넣을
  필요가 없다.

## 2. 목표

- 어시스턴트 응답이 한 번이라도 완료된 채팅은, 앱을 재시작해도 모델이 이전 대화
  맥락을 그대로 이어서 답하도록 한다.
- 대화가 길어질 때의 저장 용량/속도 최적화는 하지 않는다 — 매번 전체 `Transcript`를
  통째로 인코딩해 덮어쓰는 가장 단순한 방식으로 충분하다고 판단함(사용자 확인 완료).
  대화 압축은 이미 Phase 3 항목 3(롤링 요약, 우선순위 낮음)으로 분리되어 있다.
- 기존 `ChatSession`/`Message` struct, UI 코드는 건드리지 않는다 — transcript는
  서비스 계층(`ChatModelService`/`ChatPersistenceService`)의 관심사로 한정한다.

## 3. 아키텍처

새로 추가하는 파일은 없다. 기존 4개 파일만 변경한다.

### 3.1 `Models/ChatSessionEntity.swift`

옵셔널 필드 하나 추가:

```swift
var transcriptData: Data?
```

`init`에는 넣지 않는다 — `MessageEntity.chat`과 동일하게 옵셔널 stored property는
명시적으로 초기화하지 않아도 `nil`로 시작한다. 기존에 저장된 채팅들도 이 필드가
자동으로 `nil`이 되어 SwiftData 라이트웨이트 마이그레이션으로 문제 없이 로드된다
(이 프로젝트는 아직 `VersionedSchema`를 쓰지 않으므로 옵셔널 필드 추가가 가장 안전한
스키마 변경 방식).

### 3.2 `Services/ChatModelService.swift`

```swift
@MainActor
final class ChatModelService {

    private var session: LanguageModelSession?
    private let initialTranscript: Transcript?

    init(transcript: Transcript? = nil) {
        self.initialTranscript = transcript
    }

    var unavailableReason: String? { /* 기존과 동일 */ }

    var currentTranscript: Transcript? { session?.transcript }

    func streamResponse(to prompt: String) -> AsyncThrowingStream<String, Error> {
        /* 기존과 동일, activeSession() 호출부만 유지 */
    }

    private func activeSession() -> LanguageModelSession {
        if let session { return session }
        let session = initialTranscript.map { LanguageModelSession(transcript: $0) }
            ?? LanguageModelSession(instructions: "당신은 친절한 어시스턴트입니다. 한국어로 간결하게 답하세요.")
        self.session = session
        return session
    }
}
```

`initialTranscript`가 있으면 그걸로, 없으면 기존처럼 기본 instructions로 세션을
만든다. `currentTranscript`는 세션이 아직 한 번도 만들어지지 않았으면(모델을 한 번도
호출 안 한 채팅) `nil`.

### 3.3 `Services/ChatPersistenceService.swift`

`import FoundationModels` 추가 후 메서드 2개 추가:

```swift
func loadTranscript(forChatID chatID: ChatSession.ID) -> Transcript? {
    guard let entity = fetchEntity(id: chatID), let data = entity.transcriptData else { return nil }
    return try? JSONDecoder().decode(Transcript.self, from: data)
}

func saveTranscript(_ transcript: Transcript?, forChatID chatID: ChatSession.ID) {
    guard let transcript, let entity = fetchEntity(id: chatID) else { return }
    entity.transcriptData = try? JSONEncoder().encode(transcript)
    saveIfNeeded()
}
```

`transcript`가 `nil`이면(아직 모델을 호출한 적 없는 채팅) 아무 것도 하지 않는다 —
호출부에서 매번 nil 체크를 하지 않아도 되도록 여기서 흡수한다.

### 3.4 `ViewModels/ChatDetailViewModel.swift`

- `private let service = ChatModelService()` → `private let service: ChatModelService`로
  바꾸고 `init`에서 생성:
  ```swift
  init(chat: ChatSession, persistence: ChatPersistenceService) {
      self.chat = chat
      self.persistence = persistence
      self.service = ChatModelService(transcript: persistence.loadTranscript(forChatID: chat.id))
  }
  ```
- `sendMessage()`에서 어시스턴트 메시지를 `persistence.appendMessage`로 저장하는
  지점은 현재 총 3곳이다: ① 스트리밍 성공 완료, ② `catch` 블록 안 `assistantIndex`가
  있는 경우(부분 응답 중 에러), ③ `catch` 블록 안 `assistantIndex`가 없는 경우(첫
  조각도 못 받고 에러). 세 곳 모두 `appendMessage` 바로 다음 줄에
  `persistence.saveTranscript(service.currentTranscript, forChatID: chat.id)`를 추가한다.
- 맨 위 `unavailableReason` 조기 리턴 분기(모델을 아예 호출하지 않는 경로)에는
  추가하지 않는다 — 세션 자체가 생성되지 않아 `currentTranscript`가 항상 `nil`이라
  호출해봐야 의미가 없다.

## 4. 에러 처리 / 엣지 케이스

- **디코딩 실패** (예: 베타 API가 OS 업데이트로 바뀌어 저장된 JSON과 안 맞는 경우):
  `try?`로 조용히 `nil` 처리 → 그 채팅은 새 세션(기본 instructions)으로 시작한다.
  화면의 메시지 히스토리는 그대로 보이므로 사용자 입장에선 "모델이 이번엔 맥락을
  기억 못 하는" 정도로만 보인다 — 크래시나 기능 정지 없음.
- **인코딩/저장 실패**: 기존 `saveIfNeeded()`와 동일하게 콘솔 로그만 남기고 무시한다.
- **스트리밍 중 채팅 삭제**: 기존 `appendMessage`와 동일한 이유로 `fetchEntity`가
  `nil`을 반환해 `saveTranscript`도 조용히 no-op한다.
- **모델을 한 번도 안 부른 채팅 재시작**: `transcriptData`가 `nil`이므로 그냥
  기존처럼 기본 instructions로 세션이 생성된다 — 오늘도 이미 그런 동작이라 회귀 없음.
- **스키마 마이그레이션**: 만약 옵셔널 필드 추가만으로 자동 마이그레이션이 실패하는
  예상 밖 상황이 생겨도, 이미 있는 `ModelContainer` 생성 실패 → 인메모리 폴백이
  최후 방어선 역할을 한다.

## 5. 범위 밖 (Out of Scope)

- 롤링 요약/컨텍스트 압축 (Phase 3 항목 3, 우선순위 낮음)
- 채팅 제목 자동 생성
- Transcript 저장 용량 최적화(증분 저장, 압축 등)
- 복원 여부를 사용자에게 보여주는 UI

## 6. 수동 테스트 계획

**실기기**에서 검증한다 (Apple Intelligence 지원 기기 필요, 기존과 동일).

1. 채팅 생성 → 메시지 전송 → 응답 완료까지 대기 → 앱 완전 종료 후 재실행 → 같은
   채팅에 대화 맥락이 필요한 후속 질문(예: "방금 내가 뭐라고 물어봤지?")을 보내
   모델이 이전 대화를 실제로 기억하는지 확인
2. 메시지를 한 번도 보내지 않은 새 채팅으로 재시작 → 기존과 동일하게 정상 동작하는지
   (회귀 없음) 확인
3. 응답 도중 에러가 난 채팅도 transcript가 저장되어 재시작 후 이어지는지 확인
4. 기존에 Phase 3 항목 1로 이미 저장돼 있던(즉 `transcriptData`가 없는) 채팅을 앱
   업데이트 후 열어도 크래시 없이 정상 로드되는지 확인
