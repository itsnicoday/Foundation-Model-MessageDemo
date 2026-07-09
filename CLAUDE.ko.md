# CLAUDE.ko.md

> 이 파일은 [CLAUDE.md](CLAUDE.md)의 한국어 번역본으로, 개발자 본인의 확인용입니다. Claude Code가 실제로 읽는 파일은 CLAUDE.md이므로, 내용 수정 시 CLAUDE.md를 먼저 고치고 이 파일을 맞춰 갱신하세요.

## 프로젝트 개요

Apple의 `FoundationModels` 프레임워크로 구동되는 온디바이스 채팅 앱을 목표로 하는 SwiftUI iOS 앱입니다 (번들 ID: `com.ho.itsnicoday.Foundation-Model-MessageDemo`). 채팅 UI 셸(사이드바 + 메시지 목록 + 입력 바)은 동작하며, `Services/ChatModelService.swift`가 `LanguageModelSession`을 감쌉니다(열린 채팅당 인스턴스 하나, `ChatDetailView`의 `@State`로 보유). 참고: FoundationModels는 별도 entitlement가 필요 없지만, 이 연동 코드는 문법 체크만 거쳤을 뿐 실제 컴파일/실기기 실행은 한 번도 안 됐습니다 — Xcode가 있는 머신에서 빌드하기 전까지는 미검증 상태로 취급해야 합니다.

## 빌드 & 실행

Package.swift, CocoaPods 등 의존성 관리 도구 없음 — 순수 SwiftUI/Foundation, 단일 Xcode 프로젝트, 단일 앱 타겟(`Foundation-Model-MessageDemo`)입니다.

```bash
# 시뮬레이터용 빌드
xcodebuild -project Foundation-Model-MessageDemo.xcodeproj -scheme Foundation-Model-MessageDemo -destination 'platform=iOS Simulator,name=iPhone 16' build

# Xcode에서 열기
open Foundation-Model-MessageDemo.xcodeproj
```

공유된 `.xcscheme` 파일이 커밋되어 있지 않고 테스트 타겟도 없으므로, 현재 실행 가능한 `xcodebuild test` 명령은 없습니다. 개별 기능 확인은 빌드 후 Xcode 시뮬레이터나 프리뷰 캔버스를 직접 사용해야 합니다.

배포 타겟은 iOS 26.0, Swift 6.0, Universal(iPhone + iPad)입니다. `FoundationModels` / Apple Intelligence는 실기기 또는 캐파빌리티가 활성화된 시뮬레이터를 요구하므로, 해당 프레임워크가 연동된 이후에는 `xcodebuild build`만으로는 테스트할 수 없는 기능이 생깁니다.

## 아키텍처

순수 SwiftUI, 서드파티 의존성 없음, ObservableObject/ViewModel 계층 아직 없음 — 뷰가 `@State`/`@Binding`으로 상태를 직접 소유하며, 데이터는 인메모리 전용입니다(앱 재시작 시 모두 사라짐).

- `Foundation_Model_MessageDemoApp.swift` — `@main` 진입점, `ContentView`를 로드.
- `ContentView.swift` — 루트 뷰. `[ChatSession]` 배열과 `selectedChat`을 `@State`로 소유하는, 채팅 데이터의 단일 소스(single source of truth). `NavigationSplitView`(사이드바 + 디테일)를 호스팅. 디테일 영역은 별도의 `ChatDetailView`로 분리되어야 할 내용이 현재 인라인으로 들어가 있음(`// TODO: ChatDetailView(chat: chat)` 주석 참고) — 이 부분을 구현할 때는 `ContentView`를 계속 키우지 말고 분리해서 추출할 것.
- `Models/Message.swift` — `Message` 구조체 (`isUser: Bool`, `text: String`).
- `Views/SidebarView.swift` — 채팅 목록(생성/스와이프 삭제). 그리고 `ChatSession`(`id`, `title`, `messages`)이 이 파일 안에 인라인으로 정의되어 있음 — 이 모델은 `Models/`가 아니라 여기에 있으므로, 채팅 관련 타입을 찾을 때는 `Models/`만 보지 말고 이 파일도 확인할 것.
- `Views/Components/MessageView.swift` — 개별 메시지 말풍선. `isUser == true` 분기는 말풍선을 렌더링하지만, 어시스턴트 응답 분기는 TODO 주석만 있는 빈 `VStack`임 — 어시스턴트 메시지는 아직 전혀 렌더링되지 않음. `isLoading` 파라미터는 받지만 사용되지 않음.

`FoundationModels` 연동을 구현할 때의 자연스러운 진입점: `LanguageModelSession`을 감싸는 서비스/세션 계층(아직 없음 — 새로 만들어야 함)을 만들고, `ContentView`의 메시지 전송 플로우가 자리 잡을 곳에서 호출하며, 결과를 해당 `ChatSession`의 `messages`에 추가한 뒤 현재 비어 있는 `MessageView`의 어시스턴트 분기로 렌더링하는 구조입니다.
