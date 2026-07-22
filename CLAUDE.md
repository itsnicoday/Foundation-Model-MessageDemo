# CLAUDE.md

이 파일은 이 저장소에서 작업할 때 Claude Code(claude.ai/code)에게 방향을 제시하는 문서입니다.

## 프로젝트 개요

Apple의 `FoundationModels` 프레임워크로 구동되는 온디바이스 채팅 앱인 SwiftUI iOS 앱입니다 (번들 ID: `com.ho.itsnicoday.Foundation-Model-MessageDemo`). 채팅 UI 셸(사이드바 + 메시지 목록 + 입력 바)은 동작하며, `Services/ChatModelService.swift`가 `LanguageModelSession`을 감쌉니다(열린 채팅당 인스턴스 하나, `ChatDetailViewModel`이 소유). FoundationModels는 별도 entitlement가 필요 없습니다. 이 연동은 iOS 시뮬레이터와 실기기 양쪽에서 정상 동작(스트리밍 응답 렌더링 포함)함이 검증되었습니다.

기능 로드맵과 현재 상태는 `docs/PLAN.md`에 있습니다 — 다음에 무엇을 만들지 결정하기 전에 먼저 확인하고, 기능이 완성될 때마다 그 안의 상태 테이블도 최신으로 유지하세요.

## 빌드 & 실행

Package.swift, CocoaPods 등 의존성 관리 도구 없음 — 순수 SwiftUI/Foundation, 단일 Xcode 프로젝트, 단일 앱 타겟(`Foundation-Model-MessageDemo`)입니다.

```bash
# 시뮬레이터용 빌드 (이 머신은 xcode-select가 CommandLineTools를 가리키므로 DEVELOPER_DIR 지정 필요, iPhone 16 시뮬레이터가 없어 iPhone 17 사용)
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Foundation-Model-MessageDemo.xcodeproj -scheme Foundation-Model-MessageDemo -destination 'platform=iOS Simulator,name=iPhone 17' build

# Xcode에서 열기
open Foundation-Model-MessageDemo.xcodeproj
```

공유된 `.xcscheme` 파일이 커밋되어 있지 않고 테스트 타겟도 아직 없으므로, 현재 실행 가능한 `xcodebuild test` 명령은 없습니다 — 개별 기능을 실행/테스트하려면 빌드 후 Xcode 시뮬레이터나 프리뷰 캔버스를 직접 사용해야 합니다.

배포 타겟은 iOS 26.0, Swift 6.0, Universal(iPhone + iPad)입니다. `FoundationModels` / Apple Intelligence는 실기기 또는 캐파빌리티가 활성화된 시뮬레이터를 요구하므로, 해당 프레임워크가 연동된 이후에는 `xcodebuild build`만으로는 테스트할 수 없는 기능이 있습니다.

## 아키텍처

순수 SwiftUI, 서드파티 의존성 없음. 채팅 화면에는 가벼운 MVVM 계층(`ChatDetailViewModel`)이 있고, 채팅 데이터 전체는 `ChatViewModelStore` 하나가 단일 진실 공급원으로 관리합니다. 데이터는 SwiftData로 영속화됩니다(`ChatSessionEntity`/`MessageEntity` + `ChatPersistenceService`) — 앱을 재시작해도 대화 내역이 복원됩니다. 모델 자체의 대화 컨텍스트(`Transcript`) 복원은 아직 미구현이며, 나머지 로드맵은 `docs/PLAN.md` Phase 3에 있습니다.

- `Foundation_Model_MessageDemoApp.swift` — `@main` 진입점. `init()`에서 `ChatSessionEntity`/`MessageEntity` 스키마로 `ModelContainer`를 생성하고(생성 실패 시 인메모리 컨테이너로 폴백), 그 `mainContext`로 `ChatViewModelStore`를 `@State`로 만들어 `.environment(_:)`로 `ContentView`에 주입.
- `Stores/ChatViewModelStore.swift` — `@Observable @MainActor` 클래스. `init(modelContext:)`가 `ChatPersistenceService`를 만들고 `loadAllChats()`로 저장된 채팅을 전부 복원합니다. 채팅 id별 `ChatDetailViewModel`을 딕셔너리로 캐싱하고, 세션 목록(`chats: [ChatSession]`)은 이 캐시에서 파생되는 계산 프로퍼티입니다(별도 배열로 들고 있지 않음). `createChat(title:)` / `deleteChat(at:)` / `viewModel(for:)`을 제공하며, 생성/삭제도 `ChatPersistenceService`를 통해 디스크에 반영됩니다. 앱이 켜져 있는 동안은 채팅을 전환해도 같은 `ChatDetailViewModel` 인스턴스(와 진행 중인 스트리밍 `Task`)가 그대로 유지됩니다.
- `ContentView.swift` — 루트 뷰. `@Environment(ChatViewModelStore.self)`로 store를 읽기만 하고, 선택된 채팅의 `ChatSession.ID?`만 `@State`로 로컬 소유. `chats`나 `ChatDetailViewModel` 어느 쪽도 직접 소유하지 않으며, `ChatDetailViewModel` 타입 자체를 **모릅니다**. `NavigationSplitView`(사이드바 + 디테일)를 호스팅.
- `Models/Message.swift` — `Message` 구조체 (`id`, `isUser: Bool`, `text: String`).
- `Models/ChatSession.swift` — `ChatSession` 구조체 (`id`, `title`, `messages`).
- `Models/ChatSessionEntity.swift` — SwiftData `@Model`. 채팅 세션의 영속 표현(`id`, `title`, `createdAt`, `messages` 관계, cascade 삭제).
- `Models/MessageEntity.swift` — SwiftData `@Model`. 메시지의 영속 표현(`id`, `isUser`, `text`, `createdAt`, 소속 `chat` 역참조).
- `Models/PreviewData.swift` — `#if DEBUG` 전용. 프리뷰/시뮬레이터용 인메모리 `ModelContainer.preview`와 `Message`/`ChatSession`의 샘플 데이터를 제공.
- `Services/ChatModelService.swift` — `LanguageModelSession`을 감싸는 서비스. 채팅 하나당 인스턴스 하나로 대화 컨텍스트를 유지하고, `unavailableReason`으로 모델 사용 불가 사유를, `streamResponse(to:)`로 누적 텍스트 스트림을 제공.
- `Services/ChatPersistenceService.swift` — `ChatSessionEntity`/`MessageEntity` ↔ `ChatSession`/`Message` struct 간 변환과 CRUD를 전담. `loadAllChats()` / `createChat(_:)` / `deleteChat(id:)` / `appendMessage(_:toChatID:)`를 제공하며, 변경 후 `modelContext.save()`를 호출.
- `ViewModels/ChatDetailViewModel.swift` — `@Observable @MainActor` 클래스. `chat`, `inputText`, `isLoading`, private `ChatModelService`와 `ChatPersistenceService`, `sendMessage()`를 갖고 있음. 뷰가 아니라 `ChatViewModelStore`가 소유(캐싱)하는 주체이며, `chat`이 곧 store가 들고 있는 원본이라 부모에게 변경을 알리는 콜백이 없음. 메시지가 확정되는 체크포인트(사용자 메시지 전송 직후, 어시스턴트 응답 완료/에러 직후)마다 `persistence.appendMessage`를 호출해 저장 — 스트리밍 도중의 중간 텍스트는 저장하지 않음.
- `Views/SidebarView.swift` — 채팅 목록(생성/스와이프 삭제). 선택 상태를 `ChatSession.ID?` 기반 `Binding`으로 받음.
- `Views/ChatDetailView.swift` — 두 구조체로 분리:
  - `ChatDetailView` — `chatID: ChatSession.ID`만 받는 얇은 래퍼. `@Environment(ChatViewModelStore.self)`로 store를 읽어 `body`에서 `ChatDetailViewModel`을 조회(⚠️ `@Environment`는 커스텀 `init()` 내부에서는 아직 주입되지 않으므로 반드시 `body`에서 조회해야 함).
  - `ChatDetailContentView` — 실제 화면 로직(메시지 목록, `ScrollViewReader` 자동 스크롤, 입력 바). `init(viewModel: ChatDetailViewModel)`로 뷰모델을 직접 받음.
- `Views/Components/MessageView.swift` — 개별 메시지 말풍선. 사용자/어시스턴트 분기 모두 구현되어 있으며, `isLoading`일 때 "생각 중..." 상태도 포함.
