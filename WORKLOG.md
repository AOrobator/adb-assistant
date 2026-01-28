# Feature: Initial ADB Assistant Implementation

## Overview
Build the MVP of ADB Assistant — a native macOS logcat viewer with package-first filtering, JSON expansion, and keyboard-driven UX.

## Milestones

- [ ] M1: Project setup and core data models
- [ ] M2: ADB communication and log parsing
- [ ] M3: Log buffer and filtering
- [ ] M4: SwiftUI views and user interface
- [ ] M5: JSON detection and expansion
- [ ] M6: Keyboard shortcuts and polish
- [ ] M7: Unit and integration tests
- [ ] M8: Build script and final verification

## Invariants
- **INV-1:** No log entry is lost during pause/resume
- **INV-2:** ADB disconnect is detected within 500ms
- **INV-3:** 60fps scrolling with 100k buffered entries
- **INV-4:** JSON is automatically detected and expandable
- **INV-5:** Package-first filtering by default
- **INV-6:** Keyboard shortcuts work without mouse

## Skills Loaded
- `/adb-logcat` — ADB command patterns and integration
- `/swift-macos` — SwiftUI and macOS patterns
- `/feature-dev` — Feature development workflow

## Session Log

### Session 1 (2026-01-28)
- Created WORKLOG.md with milestones and invariants
- **Next:** Set up Xcode project structure with XcodeGen
