# AGENT.md — Project Context for AI Assistants

> This file provides essential context for AI assistants working on this project. Read first.

## Project: ADB Assistant

**A native macOS logcat viewer that doesn't suck.** Replace Android Studio's logcat for 90% of debugging workflows.

## Key Files

| File | Purpose |
|------|---------|
| `SPEC.md` | Product specification with invariants and worklog template |
| `PERSONAS.md` | Agent personas for multi-perspective reviews |
| `.agents/` | Directory containing skills and prompts |
| `research/` | Research documents on existing tools and patterns |

## Core Invariants (Must Always Hold)

1. **INV-1:** No log entry is lost during pause/resume
2. **INV-2:** ADB disconnect is detected within 500ms
3. **INV-3:** 60fps scrolling with 100k buffered entries
4. **INV-4:** JSON is automatically detected and expandable
5. **INV-5:** Package-first filtering by default
6. **INV-6:** Keyboard shortcuts work without mouse

## Tech Stack

- Swift + SwiftUI (macOS 13+)
- Native ADB integration via `Process`
- Circular buffer for log storage

## Development Workflow

1. **Read SPEC.md** — Understand requirements and invariants
2. **Load relevant skills** — Check `.agents/skills/` for patterns
3. **Create WORKLOG.md** — For features taking >1 hour
4. **Run persona reviews** — `@Security-Agent`, `@UX-Agent`, `@Mobile-Agent`
5. **Commit atomically** — 3-5 commits per feature

## Skills Available

- `/adb-logcat` — ADB command patterns and integration
- `/swift-macos` — SwiftUI and macOS patterns
- `/feature-dev` — Feature development workflow

## Quick Start

```bash
# Generate Xcode project
./build.sh

# Open in Xcode
open adb-assistant.xcodeproj
```

## Not in MVP (v1)

- Multiple device tabs
- Wireless ADB pairing
- Scrcpy integration
- APK installation
- Log persistence/sessions
