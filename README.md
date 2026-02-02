# ADB Assistant

A native macOS logcat viewer that doesn't suck.

![App Screenshot](app_screenshot.png)

## Status

🚧 **In Development** — Core filtering features working (package, level, search)

## Vision

Replace Android Studio's logcat for 90% of debugging workflows. Pidcat with a GUI, native on Mac.

## Key Features

- **Package filtering** — Filter logs by app using stable UIDs (not PIDs that change on restart)
- **Log level filtering** — Toggle V/D/I/W/E/F levels with visual indicators
- **Real-time search** — Filter logs by text in message or tag
- **Auto-device detection** — Connects automatically when device plugged in
- **JSON handling** — Auto-detect, inline expand, syntax highlight (planned)
- **Keyboard-driven** — ⌘K clear, ⌘G next match (planned)

## Tech Stack

- Swift + SwiftUI (macOS 13+)
- Native ADB integration via `Process`
- Circular buffer for high-volume log streaming

## Installation

### Option 1: Pre-built Binary

Download [adb-assistant.zip](dist/adb-assistant.zip) and unzip it.

**Note:** Since the app isn't signed with an Apple Developer certificate, macOS will block it. To run it:

```bash
# Remove quarantine attribute
xattr -cr /path/to/adb-assistant.app

# Then right-click the app and select "Open"
```

### Option 2: Build from Source

Requires Xcode 15+ and macOS 13+.

```bash
# Clone the repo
git clone https://github.com/AOrobator/adb-assistant.git
cd adb-assistant

# Build and run
xcodebuild -scheme adb-assistant -configuration Release build

# The app will be at:
# ~/Library/Developer/Xcode/DerivedData/adb-assistant-*/Build/Products/Release/adb-assistant.app
```

Or open in Xcode:

```bash
open adb-assistant.xcodeproj
# Then press ⌘R to build and run
```

## Documentation

### Spec & Research
- [SPEC.md](SPEC.md) — Full product specification
- [research/](research/) — UX research from existing tools and patterns

### Performance Reviews
- [reviews/swiftui-perf-review.md](reviews/swiftui-perf-review.md) — 8 SwiftUI issues (DateFormatter, re-renders, etc.)
- [reviews/buffer-perf-review.md](reviews/buffer-perf-review.md) — 7 buffer/streaming issues (batching, threading, timers)

### AI Collaboration
- [AGENT.md](AGENT.md) — Context for AI assistants
- [PERSONAS.md](PERSONAS.md) — Multi-agent review system
- [.agents/skills/](.agents/skills/) — Skill files for domain knowledge

## License

MIT

---

*Created by Andrew Orobator • AI assist by Zed & Kimi*
