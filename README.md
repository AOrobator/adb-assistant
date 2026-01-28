# ADB Assistant

A native macOS logcat viewer that doesn't suck.

## Status

📋 Spec phase — not yet implemented

## Vision

Replace Android Studio's logcat for 90% of debugging workflows. Pidcat with a GUI, native on Mac.

## Key Differentiators

1. **Package-first filtering** — No more PID tracking hell
2. **JSON handling** — Auto-detect, inline expand, syntax highlight
3. **Keyboard-driven** — ⌘K clear, ⌘G next match
4. **Pause-on-scroll** — Floating resume button with new log count

## Tech Stack

- Swift + SwiftUI
- macOS 13+
- Native ADB integration

## Documentation

- [SPEC.md](SPEC.md) — Full product specification
- [research/existing-tools.md](research/existing-tools.md) — Android Studio, pidcat, MatLog analysis
- [research/log-viewer-ux.md](research/log-viewer-ux.md) — Patterns from Datadog, Splunk, Grafana
- [research/mac-native-patterns.md](research/mac-native-patterns.md) — Apple HIG, SwiftUI, Console.app

---

*Created by Andrew Orobator*
