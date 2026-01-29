---
name: swiftui-loglist-performance
description: Trigger when optimizing SwiftUI log list rendering (LogListView/LogRowView), scrolling, or high-frequency UI updates.
---

# SwiftUI Log List Performance

## When to use
- Touching `LogListView`/`LogRowView` or list performance is degrading.
- Lots of log entries or rapid updates cause dropped frames.
- Auto-scroll fights user scroll or feels jittery.

## Core checklist (do these first)
1. Cache expensive formatters: `DateFormatter` (or ISO8601) must be static or shared.
2. Cache tag colors: memoize tag-to-color mapping to avoid per-render hashing.
3. Reduce per-row allocations: avoid captured closures in `ForEach`; pass IDs/bindings.
4. Limit view recomputation: make rows `Equatable` or wrap in `EquatableView`.
5. Auto-scroll stability: key `onChange` off last entry ID; cancel in-flight scroll tasks.
6. Avoid heavy work in `body`: precompute or cache background color/derived values.

## This repo quick locations
- `Sources/App/Views/LogListView.swift`

## If you need the full review
Read `references/swiftui-perf-review.md`.
