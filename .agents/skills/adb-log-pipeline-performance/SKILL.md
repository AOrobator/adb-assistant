---
name: adb-log-pipeline-performance
description: Trigger when working on ADB log streaming, LogBuffer batching, device polling, or high-throughput log ingestion in this app.
---

# ADB Log Pipeline Performance

## When to use
- Touching ADBManager, LogBuffer, or log ingestion.
- Logs arrive fast (100+ lines/sec) and UI stutters or reorders.
- Device polling or disconnect detection is expensive.

## Core checklist (do these first)
1. Batch log emissions: avoid per-entry sends; send `[LogEntry]` or collect/throttle on the subscriber.
2. Preserve ordering: process output through a single serial task/actor; avoid `Task.detached` per chunk.
3. Timers: use `DispatchSourceTimer` or main run loop for batch flush; avoid timers on background threads without run loops.
4. Avoid O(n) rebuilds per flush: incrementally append + trim; update filtered entries incrementally.
5. Cap paused buffering: limit pending entries and track dropped count.
6. Thread safety: LogBuffer must be serial (`@MainActor`/actor) or locked around shared buffers.

## This repo quick locations
- `Sources/ADBAssistant/ADB/ADBManager.swift` (streaming, polling, disconnect detection)
- `Sources/ADBAssistant/LogBuffer/LogBuffer.swift` (batching, filters, pause/resume)

## If you need the full review
Read `references/buffer-perf-review.md`.
