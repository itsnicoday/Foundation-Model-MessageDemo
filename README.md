# Foundation-Model-MessageDemo

Apple FoundationModels(온디바이스 LLM)를 활용한 SwiftUI 채팅 앱 데모입니다.

## Requirements

- Xcode 26+
- iOS 26.0+ / Apple Intelligence 지원 기기 (시뮬레이터는 모델 사용 불가할 수 있음)

## Run

1. `Foundation-Model-MessageDemo.xcodeproj` 열기
2. 시뮬레이터 또는 실기기 선택 후 실행 (⌘R)

## Architecture

```
NavigationSplitView
├─ SidebarView          채팅 목록
└─ ChatDetailView        선택된 채팅
   ├─ MessageView         말풍선 (사용자/어시스턴트)
   └─ ChatModelService → LanguageModelSession
```

| 파일 | 역할 |
|---|---|
| `Models/Message.swift` | 메시지 데이터 모델 |
| `Views/SidebarView.swift` | 채팅 목록 + `ChatSession` 모델 |
| `Views/ChatDetailView.swift` | 전송/스트리밍 UI 로직 |
| `Services/ChatModelService.swift` | `LanguageModelSession` 래핑 |

## Status

개발 진행 상황과 다음 계획은 [docs/PLAN.md](docs/PLAN.md)를 참고하세요.
빌드 명령어와 코드 컨벤션은 [CLAUDE.md](CLAUDE.md)를 참고하세요.
