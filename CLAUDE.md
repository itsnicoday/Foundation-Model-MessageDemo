# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

A SwiftUI iOS app (bundle id `com.ho.itsnicoday.Foundation-Model-MessageDemo`) that is an on-device chat app powered by Apple's `FoundationModels` framework. The chat UI shell (sidebar + message list + input bar) works, and `Services/ChatModelService.swift` wraps `LanguageModelSession` (one instance per open chat, owned by `ChatDetailViewModel`). FoundationModels needs no special entitlement. The integration has been verified working on both the iOS Simulator and a real device (streaming responses render correctly).

Feature roadmap and current status live in `docs/PLAN.md` — check it before deciding what to build next, and keep its status table up to date as features land.

## Build & run

No Package.swift, CocoaPods, or other dependency manager — pure SwiftUI/Foundation, single Xcode project, single app target (`Foundation-Model-MessageDemo`).

```bash
# Build for the simulator
xcodebuild -project Foundation-Model-MessageDemo.xcodeproj -scheme Foundation-Model-MessageDemo -destination 'platform=iOS Simulator,name=iPhone 16' build

# Open in Xcode
open Foundation-Model-MessageDemo.xcodeproj
```

There is no shared `.xcscheme` checked in and no test target in the project yet, so there is currently no `xcodebuild test` invocation to run — running/testing individual features means building and using the Xcode simulator/preview canvas directly.

Deployment target is iOS 26.0, Swift 6.0, Universal (iPhone + iPad). Because `FoundationModels` / Apple Intelligence requires a real device or a simulator with the capability enabled, some functionality won't be testable via `xcodebuild build` alone once that framework is wired in.

## Architecture

Plain SwiftUI, no third-party dependencies. There is a lightweight MVVM layer for the chat screen (`ChatDetailViewModel`); everything else still owns state directly via `@State`/`@Binding`. Data is in-memory only (nothing persists across launches).

- `Foundation_Model_MessageDemoApp.swift` — `@main` entry point, loads `ContentView`.
- `ContentView.swift` — root view. Owns the `[ChatSession]` array and `selectedChat` as `@State`, and is the single source of truth for chat data (used by `SidebarView` for the chat list/previews). It does **not** know about `ChatDetailViewModel` — it hands `ChatDetailView` a plain `ChatSession` value plus an `onUpdate: (ChatSession) -> Void` callback, and tags it with `.id(selectedChat.id)` so switching chats gets a fresh view/view-model instance. Hosts a `NavigationSplitView` (sidebar + detail).
- `Models/Message.swift` — `Message` struct (`isUser: Bool`, `text: String`).
- `Models/ChatSession.swift` — `ChatSession` struct (`id`, `title`, `messages`). Previously lived inline in `SidebarView.swift`; moved out.
- `ViewModels/ChatDetailViewModel.swift` — `@Observable @MainActor` class owned by `ChatDetailView` (created in its `init`, held via `@State`). Holds `chat`, `inputText`, `isLoading`, a private `ChatModelService`, and `sendMessage()`. Whenever `chat` changes it's reported to the parent via the `onUpdate` closure passed into `ChatDetailView`'s init — that's the only path back to `ContentView.chats`.
  - Known limitation: because `ContentView` recreates `ChatDetailView` (and thus the view model) via `.id()` on chat switch, navigating away mid-stream or with a draft in the input field loses that in-flight state — only what was already synced via `onUpdate` survives. If this needs to persist across chat switches, a view-model cache keyed by chat id (owned by a dedicated store, not by `ContentView` directly) would be the next step.
- `Views/SidebarView.swift` — chat list (create/delete via swipe). No longer defines `ChatSession` (see `Models/ChatSession.swift`).
- `Views/ChatDetailView.swift` — message list (`ScrollViewReader` + auto-scroll to the latest message/loading indicator on change) + input bar. Takes `chat: ChatSession` and `onUpdate` in its init, not a `Binding<ChatSession>`.
- `Views/Components/MessageView.swift` — single message bubble; both the user and assistant branches are implemented, including the `isLoading` "생각 중..." state.
