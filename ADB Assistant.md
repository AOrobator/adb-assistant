# ADB Assistant

A native macOS logcat viewer that doesn't suck.

## Status
📋 Spec phase — not yet implemented

## Documents
- [[SPEC]] — Full product specification
- **Research:**
  - [[research/existing-tools|Existing Tools]] — Android Studio, pidcat, MatLog analysis
  - [[research/log-viewer-ux|Log Viewer UX]] — Patterns from Datadog, Splunk, Grafana
  - [[research/mac-native-patterns|Mac Native Patterns]] — Apple HIG, SwiftUI, Console.app

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

---
*Created: 2026-01-28*
