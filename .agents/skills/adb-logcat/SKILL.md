---
name: adb-logcat
description: Trigger when working with ADB logcat commands, device log streaming, or log parsing.
---

# ADB Logcat Patterns

## Core Commands

```bash
# Basic logcat streaming
adb logcat

# Filter by tag
adb logcat -s "MainActivity"

# Filter by log level (V, D, I, W, E, A, S)
adb logcat *:I

# Filter by package (requires -d for non-continuous)
adb logcat --pid=$(adb shell pidof com.example.app)

# Clear log buffer
adb logcat -c

# Get recent logs (non-blocking)
adb logcat -d
```

## Swift Integration

```swift
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/adb")
process.arguments = ["shell", "logcat", "-d"]

let pipe = Pipe()
process.standardOutput = pipe

try process.run()
let data = pipe.fileHandleForReading.readDataToEndOfFile()
let output = String(data: data, encoding: .utf8)
```

## Log Format Options

- `--format=brief` — Default, shows priority/tag and PID
- `--format=long` — Full XML-like output
- `--format=process` — Shows PID only
- `--format=tag` — Shows tag only
- `--format=thread` — Shows PID and TID
- `--format=raw` — Raw message only
- `--format=time` — Date and time
- `--format=threadtime` — Default + time (recommended)

## Common Filters

```bash
# System logs only
adb logcat -b system

# Crash logs
adb logcat -b crash

# Main log buffer (default)
adb logcat -b main

# All buffers
adb logcat -b all
```

## Exit Codes

- 0 — Success
- 1 — No devices/emulators found
- 2 — Invalid arguments

## Error Handling

Check `stderr` for:
- "error: no devices/emulators found"
- "error: device offline"
- "error: unknown option"
