# CLAUDE.md

이 파일은 이 저장소에서 작업할 때 Claude Code(claude.ai/code)에게 방향을 제시하는 문서입니다.

## 프로젝트 개요

Apple의 `FoundationModels` 프레임워크로 구동되는 온디바이스 채팅 앱인 SwiftUI iOS 앱입니다 (번들 ID: `com.ho.itsnicoday.Foundation-Model-MessageDemo`). 채팅 UI 셸(사이드바 + 메시지 목록 + 입력 바)은 동작하며, `Services/ChatModelService.swift`가 `LanguageModelSession`을 감쌉니다(열린 채팅당 인스턴스 하나, `ChatDetailViewModel`이 소유). FoundationModels는 별도 entitlement가 필요 없습니다. 이 연동은 iOS 시뮬레이터와 실기기 양쪽에서 정상 동작(스트리밍 응답 렌더링 포함)함이 검증되었습니다.

기능 로드맵과 현재 상태는 `docs/PLAN.md`에 있습니다 — 다음에 무엇을 만들지 결정하기 전에 먼저 확인하고, 기능이 완성될 때마다 그 안의 상태 테이블도 최신으로 유지하세요.

## 빌드 & 실행

Package.swift, CocoaPods 등 의존성 관리 도구 없음 — 순수 SwiftUI/Foundation, 단일 Xcode 프로젝트, 단일 앱 타겟(`Foundation-Model-MessageDemo`)입니다.

```bash
# 시뮬레이터용 빌드
xcodebuild -project Foundation-Model-MessageDemo.xcodeproj -scheme Foundation-Model-MessageDemo -destination 'platform=iOS Simulator,name=iPhone 16' build

# Xcode에서 열기
open Foundation-Model-MessageDemo.xcodeproj
```

공유된 `.xcscheme` 파일이 커밋되어 있지 않고 테스트 타겟도 아직 없으므로, 현재 실행 가능한 `xcodebuild test` 명령은 없습니다 — 개별 기능을 실행/테스트하려면 빌드 후 Xcode 시뮬레이터나 프리뷰 캔버스를 직접 사용해야 합니다.

배포 타겟은 iOS 26.0, Swift 6.0, Universal(iPhone + iPad)입니다. `FoundationModels` / Apple Intelligence는 실기기 또는 캐파빌리티가 활성화된 시뮬레이터를 요구하므로, 해당 프레임워크가 연동된 이후에는 `xcodebuild build`만으로는 테스트할 수 없는 기능이 있습니다.

## 아키텍처

순수 SwiftUI, 서드파티 의존성 없음. 채팅 화면에는 가벼운 MVVM 계층(`ChatDetailViewModel`)이 있고, 그 외에는 여전히 뷰가 `@State`/`@Binding`으로 상태를 직접 소유합니다. 데이터는 인메모리 전용입니다(앱 재시작 시 모두 사라짐).

- `Foundation_Model_MessageDemoApp.swift` — `@main` 진입점, `ContentView`를 로드.
- `ContentView.swift` — 루트 뷰. `[ChatSession]` 배열과 `selectedChat`을 `@State`로 소유하며, 채팅 데이터의 단일 소스(single source of truth)입니다(`SidebarView`의 채팅 목록/미리보기에도 이 데이터를 사용). `ChatDetailViewModel`의 존재는 **모릅니다** — `ChatDetailView`에 순수 `ChatSession` 값과 `onUpdate: (ChatSession) -> Void` 콜백만 넘기고, `.id(selectedChat.id)`를 붙여서 채팅을 전환할 때마다 새 뷰/뷰모델 인스턴스가 생기도록 합니다. `NavigationSplitView`(사이드바 + 디테일)를 호스팅.
- `Models/Message.swift` — `Message` 구조체 (`isUser: Bool`, `text: String`).
- `Models/ChatSession.swift` — `ChatSession` 구조체 (`id`, `title`, `messages`). 예전에는 `SidebarView.swift`에 인라인으로 정의되어 있었으나 이곳으로 옮김.
- `ViewModels/ChatDetailViewModel.swift` — `ChatDetailView`가 소유하는 `@Observable @MainActor` 클래스(`init`에서 생성해 `@State`로 보유). `chat`, `inputText`, `isLoading`, private `ChatModelService`, `sendMessage()`를 갖고 있음. `chat`이 바뀔 때마다 `ChatDetailView`의 init에 전달된 `onUpdate` 클로저로 부모에 알림 — 이것이 `ContentView.chats`로 돌아가는 유일한 경로.
  - 알려진 제약: `ContentView`가 채팅 전환 시 `.id()`로 `ChatDetailView`(와 뷰모델)를 새로 만들기 때문에, 스트리밍 중이거나 입력창에 draft가 남아있는 상태로 다른 채팅으로 이동하면 그 진행 상태는 사라짐 — `onUpdate`로 이미 동기화된 부분만 남음. 채팅 전환 간에도 이 상태를 유지해야 한다면, 채팅 id별 뷰모델 캐시(를 `ContentView`가 아니라 별도 store가 소유하는 형태)를 다음 단계로 검토.
- `Views/SidebarView.swift` — 채팅 목록(생성/스와이프 삭제). 더 이상 `ChatSession`을 정의하지 않음(`Models/ChatSession.swift` 참고).
- `Views/ChatDetailView.swift` — 메시지 목록(`ScrollViewReader` + 새 메시지/로딩 상태 변경 시 자동 스크롤) + 입력 바. init에서 `chat: ChatSession`과 `onUpdate`를 받으며, `Binding<ChatSession>`은 사용하지 않음.
- `Views/Components/MessageView.swift` — 개별 메시지 말풍선. 사용자/어시스턴트 분기 모두 구현되어 있으며, `isLoading`일 때 "생각 중..." 상태도 포함.
