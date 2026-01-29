# ADB Assistant

A native macOS logcat viewer that doesn't suck.

![App Screenshot](app_screenshot.png)

## Status

🚧 **In Development** — MVP functional, fixing performance issues

## Vision

Replace Android Studio's logcat for 90% of debugging workflows. Pidcat with a GUI, native on Mac.

## Key Features

- **Package-first filtering** — No more PID tracking hell
- **JSON handling** — Auto-detect, inline expand, syntax highlight
- **Keyboard-driven** — ⌘K clear, ⌘G next match
- **Pause-on-scroll** — Floating resume button with new log count
- **Auto-device detection** — Connects automatically when device plugged in

## Tech Stack

- Swift + SwiftUI (macOS 13+)
- Native ADB integration via `Process`
- Circular buffer for high-volume log streaming

## Building

```bash
# Generate Xcode project
./build.sh

# Open in Xcode
open adb-assistant.xcodeproj
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

## Known Issues

See [reviews/](reviews/) for detailed analysis. Top priorities:

| Issue | Impact | Fix |
|-------|--------|-----|
| DateFormatter created every render | Frame drops | Static cached formatter |
| Batching sends entries one-at-a-time | 50x UI updates | Send as batch array |
| Timer scheduled from background thread | May not fire | Use DispatchSourceTimer |
| No thread safety on batchBuffer | Potential crash | Make LogBuffer an actor |

## License

MIT

---

*Created by Andrew Orobator • AI assist by Zed & Kimi*
