# Foundation-Model-MessageDemo 기획서

> Apple FoundationModels(온디바이스 LLM)를 활용한 채팅 앱 데모.
> 최종 수정: 2026-07-09

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
| FoundationModels 응답 생성 | 🔨 구현됨 (실기기 검증 전) |
| 응답 스트리밍 (타자 치듯 출력) | 🔨 구현됨 (실기기 검증 전) |
| 로딩 상태 표시 ("생각 중...") | ✅ 완료 |
| 채팅 영속성 (재시작 후 유지) | ❌ 미구현 |

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

### Phase 2 — FoundationModels 연동 (핵심)
- [x] `LanguageModelSession`을 감싸는 서비스 계층 생성 (`Services/ChatModelService.swift`)
- [x] 전송 → 온디바이스 모델 응답 → 메시지 추가 플로우 연결 (임시 에코 제거)
- [x] 모델 사용 불가 상황 처리 (미지원 기기/AI 꺼짐/모델 준비 중 → 안내 메시지)
- [x] 응답 스트리밍 처리 (`ChatModelService.streamResponse`, 첫 조각 도착 시 로딩 인디케이터 → 텍스트로 전환, 이후 누적 텍스트로 갱신)
- [ ] 실기기(Apple Intelligence 지원)에서 동작 검증 — 이 머신엔 SDK가 없어 문법 체크만 완료
      (`streamResponse(to:)`가 매 조각마다 "누적 전체 텍스트"를 준다는 가정하에 구현 — 델타 방식이면 조정 필요)
- [ ] (알려진 제약) 채팅 이탈 후 복귀 시 모델 컨텍스트 초기화 — transcript 복원은 추후 검토

### Phase 3 — 완성도
- [ ] 채팅 영속성 (SwiftData 검토)
- [ ] 채팅 제목 자동 생성 (첫 메시지 기반)
- [ ] `ChatSession`을 `Models/`로 이동 등 코드 정리

## 5. 제약 / 참고

- **배포 타겟 iOS 26.0, Swift 6.0** — FoundationModels는 Apple Intelligence 지원 기기 필요
- 개발 머신에는 Xcode 없음 → 빌드/실행 검증은 별도 머신에서 진행
- FoundationModels는 별도 entitlement 없이 사용 가능한 것으로 알려짐 — 실기기 검증 시 확인
