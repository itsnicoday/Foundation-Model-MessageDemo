# Foundation-Model-MessageDemo 기획서

> Apple FoundationModels(온디바이스 LLM)를 활용한 채팅 앱 데모.
> 최종 수정: 2026-07-23

## 1. 목표

- Apple Intelligence의 **FoundationModels 프레임워크를 직접 다뤄보는 학습용 데모 앱**
- 네트워크 없이 **온디바이스에서 동작하는 ChatGPT 스타일 채팅 경험** 구현
- 외부 의존성 없이 순수 SwiftUI로 구성 (현재 유지 중)

## 2. 핵심 기능

| 기능 | 상태 |
|---|---|
| 채팅 목록 사이드바 (생성/삭제) | ✅ 완료 |
| 채팅 상세 화면 + 입력 바 | ✅ 완료 (응답은 임시 에코) |
| 사용자 메시지 말풍선 | ✅ 완료 |
| 어시스턴트 메시지 말풍선 | ✅ 완료 |
| FoundationModels 응답 생성 | ✅ 완료 (실기기 검증됨) |
| 응답 스트리밍 (타자 치듯 출력) | ✅ 완료 (실기기 검증됨) |
| 로딩 상태 표시 ("생각 중...") | ✅ 완료 |
| 채팅 영속성 (재시작 후 유지) | ✅ 완료 (SwiftData, 모델 컨텍스트 복원은 별도) |

## 3. 화면 구성

```
NavigationSplitView
├─ SidebarView          채팅 목록, 새 채팅 버튼, 스와이프 삭제
└─ ChatDetailView       선택된 채팅
   ├─ 메시지 리스트      MessageView (사용자/어시스턴트 말풍선)
   └─ 입력 바           TextField + 전송 버튼
```

## 4. 개발 단계

### Phase 1 — 채팅 동작 완성 ✅ (2026-07-09)
- [x] 메시지 전송 시 `ChatSession.messages`에 추가되도록 데이터 흐름 정리
      (`ChatDetailView`의 `chat`을 `@Binding`으로 변경, ContentView가 배열 바인딩 전달)
- [x] 어시스턴트 말풍선 UI 구현 (`MessageView`의 빈 분기)
- [x] 로딩 상태 표시 ("생각 중..." + ProgressView, 응답은 1초 딜레이 임시 에코)

### Phase 2 — FoundationModels 연동 (핵심) ✅ (2026-07-16)
- [x] `LanguageModelSession`을 감싸는 서비스 계층 생성 (`Services/ChatModelService.swift`)
- [x] 전송 → 온디바이스 모델 응답 → 메시지 추가 플로우 연결 (임시 에코 제거)
- [x] 모델 사용 불가 상황 처리 (미지원 기기/AI 꺼짐/모델 준비 중 → 안내 메시지)
- [x] 응답 스트리밍 처리 (`ChatModelService.streamResponse`, 첫 조각 도착 시 로딩 인디케이터 → 텍스트로 전환, 이후 누적 텍스트로 갱신)
- [x] 시뮬레이터에서 빌드 및 동작 확인 (`streamResponse(to:)`가 `Snapshot.content`로 누적 전체 텍스트를 준다는 것 확인, 타입 불일치 수정)
- [x] 실기기(Apple Intelligence 지원)에서 동작 검증 완료
- [x] (알려진 제약) 채팅 이탈 후 복귀 시 모델 컨텍스트 초기화 — 앱이 켜져 있는 동안은 Phase 3 "0. 뷰모델 캐싱 계층"으로 해소(2026-07-16). 앱 재시작 후 복원은 Phase 3의 남은 하위 항목(SwiftData·Transcript) 참고

### Phase 3 — 완성도
- [ ] 채팅 영속성 & 모델 컨텍스트 복원 (우선순위 순 — "나갔다 들어오면 세션이 끊긴다"는 물리적 한계가 아니라
      지금의 `.id()` 리셋 아키텍처 때문이므로, 앱 실행 중/재시작 후를 나눠서 단계적으로 해소)
  - [x] **0. 뷰모델 캐싱 계층**: ✅ (2026-07-16) `ChatViewModelStore`(`Stores/ChatViewModelStore.swift`) 도입 완료.
        채팅 id별로 `ChatDetailViewModel`(과 내부 `LanguageModelSession`)을 계속 살려두고, 세션 목록(`chats`)도
        이 캐시에서 파생시켜 `ContentView`/`SidebarView`가 더 이상 `ChatSession` 배열을 따로 소유하지 않도록
        통합함. 앱이 켜져 있는 동안은 다른 채팅 갔다가 돌아와도 스트리밍/입력 draft가 끊기지 않음을
        시뮬레이터에서 수동 검증(스트리밍 중 전환/복귀, 스트리밍 중 삭제 모두 정상). SwiftData나 별도 저장
        없이 가장 저렴하게 해결되는 부분.
        스펙: `docs/superpowers/specs/2026-07-16-chat-viewmodel-store-design.md`,
        계획: `docs/superpowers/plans/2026-07-16-chat-viewmodel-store.md`.
  - [x] **1. SwiftData로 메시지 영속화**: ✅ (2026-07-16) `ChatSessionEntity`/`MessageEntity`(`@Model`)와
        `ChatPersistenceService`(`Services/ChatPersistenceService.swift`) 추가, `ChatViewModelStore`/
        `ChatDetailViewModel`을 여기 연결. 앱 시작 시 `ChatViewModelStore.init(modelContext:)`가
        `loadAllChats()`로 저장된 대화를 전부 복원하고, 사용자 메시지 전송 직후·어시스턴트 응답
        완료/에러 직후 체크포인트마다 `appendMessage`로 저장(스트리밍 중간 텍스트는 저장 안 함).
        `Foundation_Model_MessageDemoApp.swift`가 `ModelContainer`를 생성(실패 시 인메모리로 폴백).
        단, 이것만으로는 화면에 보이는 텍스트만 복원되고 모델 자체의 컨텍스트는 복원되지 않음 —
        아래 "2. Transcript 저장/복원" 참고.
        스펙: `docs/superpowers/specs/2026-07-16-swiftdata-persistence-design.md`,
        계획: `docs/superpowers/plans/2026-07-16-swiftdata-persistence.md`.
  - [ ] **2. `Transcript` 저장/복원**: FoundationModels의 `Transcript`(Codable 여부·정확한 API는 베타라
        Xcode에서 재확인 필요)를 SwiftData 필드로 같이 저장했다가, 채팅 재진입 시
        `LanguageModelSession(transcript:)` 형태로 재구성 — 앱 재시작 후에도 모델이 이전 대화를
        "기억"하게 하는 더 충실한 방법.
  - [ ] **3. 롤링 요약(대화 압축)**: 대화가 길어져 컨텍스트 윈도우 한계에 걸리기 시작하면, 일정 턴마다
        모델에게 스스로 요약을 시켜 그 요약을 다음 세션의 instructions로 주입. 대화 길이가 실제
        문제가 될 때 추가할 나중 단계 최적화 (지금 단계에서는 우선순위 낮음).
- [ ] 채팅 제목 자동 생성 (첫 메시지 기반)
- [x] `ChatSession`을 `Models/`로 이동 (기존 `SidebarView.swift` 내부 정의 제거)
- [x] `ChatDetailViewModel` 도입 (`@Observable`, `ViewModels/`) — 이후 `ChatViewModelStore`(위 Phase 3
      "0. 뷰모델 캐싱 계층")가 채팅 id별로 인스턴스를 캐싱하는 형태로 발전. `onUpdate` 콜백은 제거되었고,
      `ContentView`는 여전히 `ChatDetailViewModel` 타입을 모르며 store를 통해서만 간접적으로 다룸.
- [x] 메시지 목록 자동 스크롤 (`ScrollViewReader`, 새 메시지/로딩 상태 변경 시 하단으로 스크롤)

## 5. 제약 / 참고

- **배포 타겟 iOS 26.0, Swift 6.0** — FoundationModels는 Apple Intelligence 지원 기기 필요
- Xcode로 빌드 확인됨 (iOS 26.5 시뮬레이터, `xcodebuild ... build` 성공), 실기기 동작도 검증 완료
- FoundationModels는 별도 entitlement 없이 사용 가능함을 실기기에서 확인
