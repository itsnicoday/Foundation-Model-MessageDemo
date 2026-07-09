# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

A SwiftUI iOS app (bundle id `com.ho.itsnicoday.Foundation-Model-MessageDemo`) intended to be an on-device chat app powered by Apple's `FoundationModels` framework. The chat UI shell (sidebar + message list + input bar) works, and `Services/ChatModelService.swift` wraps `LanguageModelSession` (one instance per open chat, held as `@State` in `ChatDetailView`). Note: FoundationModels needs no special entitlement, but the integration has only been syntax-checked, never compiled or run on a device — treat it as unverified until someone builds it on a machine with Xcode.

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

Plain SwiftUI, no third-party dependencies, no ObservableObject/ViewModel layer yet — views own state directly via `@State`/`@Binding`, and data is in-memory only (nothing persists across launches).

- `Foundation_Model_MessageDemoApp.swift` — `@main` entry point, loads `ContentView`.
- `ContentView.swift` — root view. Owns the `[ChatSession]` array and `selectedChat` as `@State`, and is the single source of truth for chat data. Hosts a `NavigationSplitView` (sidebar + detail). The detail pane currently inlines what should be a separate `ChatDetailView` (see the `// TODO: ChatDetailView(chat: chat)` comment) — when building that out, extract it rather than continuing to grow `ContentView`.
- `Models/Message.swift` — `Message` struct (`isUser: Bool`, `text: String`).
- `Views/SidebarView.swift` — chat list (create/delete via swipe), and also defines `ChatSession` inline (`id`, `title`, `messages`) — note this model lives here rather than in `Models/`, so check this file (not just `Models/`) when looking for chat-related types.
- `Views/Components/MessageView.swift` — single message bubble. The `isUser == true` branch renders a bubble; the assistant-reply branch is an empty `VStack` with only TODO comments — assistant messages are not rendered at all yet. `isLoading` is accepted as a param but unused.

When implementing the `FoundationModels` integration, the natural entry points are: a service/session layer that wraps `LanguageModelSession` (doesn't exist yet — will need to be created), invoked from wherever `ContentView`'s chat-sending flow ends up living, with results appended to a `ChatSession`'s `messages` and rendered via the currently-empty assistant branch of `MessageView`.
