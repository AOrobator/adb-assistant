# Log Viewer UX Research

Research compilation for building a native Mac logcat viewer. Covers patterns from professional log management tools (Datadog, Splunk, Grafana Loki, Papertrail, Kibana) and open-source log viewers.

---

## 1. Handling High-Volume Streaming Data

### The Core Challenge
Professional log viewers must handle thousands to millions of log entries while remaining responsive. The key insight: **never try to render everything at once**.

### Patterns from Professional Tools

#### Virtual Scrolling / Windowed Rendering
- **Only render visible rows** - Datadog, Splunk, and Kibana all use virtualized lists
- Keep a buffer of ~50-100 rows above/below viewport for smooth scrolling
- Recycle DOM elements as user scrolls (row pooling)
- For native Mac: NSTableView with estimated row heights, or SwiftUI's LazyVStack

#### Buffer Management (Logdy Pattern)
```
--max-message-count int    Max messages stored in buffer (default 100000)
--bulk-window int          Batch messages before sending to UI (default 100ms)
```
- Store logs in a circular buffer with configurable max size
- On overflow, drop oldest messages (FIFO)
- Batch updates to UI in time windows (50-100ms) to prevent render thrashing

#### The "Tail" vs "Pause" Paradigm
Professional tools all implement this critical UX pattern:
1. **Live Tail Mode**: Auto-scroll to bottom, new logs appear instantly
2. **Paused/Browsing Mode**: User scrolls up → automatically pause tail
3. **Resume Indicator**: Floating button shows "X new logs" with one-click resume

**Papertrail's approach:**
> "Live tail - Seek by time - Context - Elegant search"
- Live tail is the default experience
- Seeking by time pauses the stream
- Clear visual indicator of current mode

#### Chunked Loading for Historical Data
LogViewer (sevdokimov) insight:
> "LogViewer can show huge log files without significant resource consumption because it reads only the part of the file that a user is watching. No indexing."

- Load chunks on-demand as user scrolls
- Use file offsets for random access
- Only parse what's needed for display

### Implementation Recommendations for Mac Logcat
1. **Virtualized table** using NSTableView or custom SwiftUI LazyVStack
2. **Circular buffer** of 50,000-100,000 entries (configurable)
3. **Batch UI updates** at 60fps max (16ms batches)
4. **Auto-pause on scroll** with floating "resume" button showing count
5. **Time-based seeking** for historical navigation

---

## 2. Filtering Patterns - What Makes It Intuitive

### The Simple Search Box is King
From Nielsen Norman Group research:
> "Users scan the homepage looking for 'the little box where I can type.'"
> "Search should be a type-in field and not a link."
> "The search input field should be wide enough to contain the typical query."

**Key insight:** Users are terrible at query reformulation. First search success rate: 51%. By third attempt: 18%.

### Layered Filtering Architecture

#### Tier 1: Quick Filters (Always Visible)
- **Log Level toggles** - Checkboxes or pills for V/D/I/W/E/F
- **Process/Package filter** - Dropdown or autocomplete
- **Tag filter** - Searchable dropdown
- These should be ONE CLICK to toggle

#### Tier 2: Search Bar
- Free-text search across all visible fields
- Should work without knowing query syntax
- Show results as user types (incremental/live search)

#### Tier 3: Advanced Filters (Expandable)
- Date/time range picker
- Regex patterns
- Custom JavaScript/expression filters (power users)
- **Don't show by default** - users misuse advanced search

### Splunk's Filter Operators (Adapted for Logcat)
```
level=error              # Exact match
level!=debug             # Exclusion  
tag=MyActivity           # Tag filter
message~"failed"         # Contains (regex)
pid IN (1234, 5678)      # Multiple values
```

### Grafana Loki Pattern - Stream Selection Then Filtering
```
{app="myapp", level="error"} |= "timeout" | duration > 10s
```
1. First, select the log stream (app, device, process)
2. Then apply line filters (contains, regex)
3. Then label/field filters

### Filter State Management
- **Filters should be URL-shareable** - Encode filter state in URL
- **Saved filters/views** - Let users save common filter combinations
- **Clear all button** - One-click reset to default view
- **Show active filter count** - Badge showing "3 filters active"

### Auto-Complete & Suggestions
From Datadog Log Explorer:
> "To start creating queries and using facets in the Log Explorer, read Log Search Syntax"

- Autocomplete tag names, package names, process IDs
- Show recent searches
- Suggest common filters based on visible data

---

## 3. Color Coding and Visual Hierarchy

### Standard Log Level Colors (Industry Convention)

| Level | Color | Hex (Dark Theme) | Hex (Light Theme) |
|-------|-------|------------------|-------------------|
| Verbose | Gray | `#808080` | `#666666` |
| Debug | Blue | `#4A9EFF` | `#0066CC` |
| Info | Green | `#4CAF50` | `#2E7D32` |
| Warning | Yellow/Amber | `#FFC107` | `#F57C00` |
| Error | Red | `#F44336` | `#D32F2F` |
| Fatal/Assert | Dark Red/Magenta | `#9C27B0` | `#880E4F` |

### VS Code Log File Highlighter Pattern
```json
{
  "pattern": "ERROR|ERR",
  "foreground": "#f00"
},
{
  "pattern": "DEBUG|DBG", 
  "foreground": "#00f"
}
```

### Beyond Level: Additional Visual Hierarchy

#### Row-Level Styling
- **Background tint** by level (subtle, not overwhelming)
- **Left border/gutter** with level color (Android Studio pattern)
- **Bold timestamps** for time gaps > N seconds
- **Dimmed** verbose/debug in high-volume scenarios

#### Field-Level Styling (klp pattern)
> "Focus on Essentials: Instantly highlight key fields: timestamp, log level, and message."

- **Timestamp**: Monospace, muted color
- **Tag/Logger**: Distinct color, possibly truncated
- **PID/TID**: Small, gray, optional display
- **Message**: Primary text, highest contrast

#### Visual Markers for Anomalies (Datadog Watchdog)
> "Watchdog Insights surface anomalous logs and outliers in error logs"

- Highlight log spikes/bursts
- Mark repeated error patterns
- Show time gaps visually

### Dark vs Light Theme Considerations
- Colors must maintain WCAG contrast ratios (4.5:1 minimum)
- Test colors in both themes before shipping
- Error red should never be confused with selection highlight

---

## 4. Search UX in Real-Time Streams

### The Fundamental Tension
Real-time streaming creates a unique UX challenge: **search results become stale instantly**.

### Pattern 1: Search Pauses Stream (Recommended)
When user starts typing in search:
1. Pause incoming logs (buffer in background)
2. Show search results from current buffer
3. New matching logs accumulate in indicator: "12 new matches"
4. User clicks to incorporate new results

### Pattern 2: Live Search Highlighting
- Don't filter, just highlight matches
- Works well at low volume (<100 logs/sec)
- At high volume, highlighting can cause visual noise

### Pattern 3: Search Creates a New View (Kibana/Datadog)
> "Save your Discover sessions to reuse later, add them to dashboards"

- Search opens a filtered view
- Original stream continues in background tab
- User can toggle between views

### Search Features Checklist

#### Must Have
- [ ] Case-insensitive by default (toggle for case-sensitive)
- [ ] Incremental/live results as user types
- [ ] Highlight matches in results
- [ ] Clear visual feedback when no matches
- [ ] Previous/Next navigation for matches (F3/Shift+F3)
- [ ] Match count display ("23 of 456 matches")

#### Nice to Have
- [ ] Regex support (toggle)
- [ ] Field-specific search (`tag:MyActivity`)
- [ ] Search history (recent searches dropdown)
- [ ] Search in visible vs all buffered logs toggle

### Search Performance Considerations
From LogViewer research:
> "Parsing 1GB file takes 3.5 sec on my machine. It is viable."

- Search should never block UI
- Run search on background thread
- Show incremental results
- Allow cancellation of long-running searches

---

## 5. Finding the Needle - Highlighting, Bookmarks, Navigation

### Highlighting Patterns

#### Multi-Color Highlighting (IntelliJ Pattern)
> "Highlighting fields, lines, parent brackets. Highlighting makes the log much more readable."

Allow users to highlight different terms in different colors:
- Search term: Yellow background
- User highlight 1: Green background
- User highlight 2: Blue background
- etc.

#### Persistent Highlights
Let users mark specific text patterns that persist:
- Right-click → "Highlight all occurrences"
- Shows in minimap/scrollbar
- Survives across filter changes

### Bookmarking System

#### Basic Bookmarks
- Keyboard shortcut (Cmd+B) to bookmark current line
- Visual indicator (star/flag in gutter)
- Bookmark panel listing all bookmarks with preview
- Jump to next/previous bookmark (F2/Shift+F2)

#### Smart Bookmarks (LogViewer Pattern)
> "A permanent link to a log position. A user can copy a link to the current position and send it to another user."

- Bookmark includes timestamp, not line number (lines can shift)
- Shareable bookmark URLs
- Export bookmark set for collaboration

### Navigation Tools

#### Timeline/Minimap View
Visual overview of the entire log:
- Dense representation in scrollbar or sidebar
- Color-coded by log level
- Click to jump to position
- Shows density of errors/warnings

#### Time-Based Navigation (Papertrail "Seek by Time")
> "Seek by time - Context"

- Date/time picker to jump to specific moment
- "Go to timestamp" input field
- Keyboard shortcuts for time jumps:
  - `[` / `]` - Jump to previous/next error
  - `{` / `}` - Jump backward/forward 1 minute
  - `Cmd+G` - Go to timestamp dialog

#### Context Preservation
When navigating to a match:
- Show N lines before and after (configurable context)
- Fold/expand context as needed
- Never lose where you came from (back button/history)

### Folding & Expansion (LogViewer Pattern)
> "Folding secondary information like unmeaning parts of exception stacktraces"

- Auto-fold long stack traces to first few lines
- Click to expand
- "Expand all" / "Collapse all" toggle
- Remember fold state for similar patterns

### Pattern Detection
> "Get statistics about the number of events and the occurring log levels, visually mark time gaps between events and see a succinct map of log level patterns."

- Detect and group repeated log patterns
- "This error occurred 47 times in last 5 minutes"
- Cluster similar stack traces
- Time gap indicators between bursts

---

## 6. Mac-Native Considerations

### Platform Conventions
- Use native NSTableView/SwiftUI List for scrolling behavior
- Respect system color scheme (dark/light mode)
- Support trackpad gestures (pinch to zoom text, two-finger scroll)
- Keyboard shortcuts should match macOS conventions

### Performance on M-Series Chips
- Leverage Metal for rendering large lists
- Use GCD/async-await for background operations
- Memory-map large log files when possible

### System Integration
- Spotlight integration for searching saved log sessions
- Handoff support between Mac and iOS companion app
- Share sheet integration for exporting logs

---

## 7. Summary: Key Patterns for Native Mac Logcat Viewer

### Core Architecture
1. **Virtualized list** rendering (only visible rows)
2. **Circular buffer** for log storage (configurable size)
3. **Background parsing** thread with batched UI updates
4. **Pause-on-scroll** with resume indicator

### Filter UX
1. **One-click level filters** always visible
2. **Simple search box** with autocomplete
3. **Advanced filters** hidden by default
4. **Saved filter presets**

### Visual Design
1. **Industry-standard level colors** with dark/light variants
2. **Subtle row backgrounds**, prominent left gutter
3. **Monospace font** for logs
4. **Minimap** in scrollbar

### Search & Navigation
1. **Incremental search** with match count
2. **Multi-term highlighting** in different colors
3. **Bookmarks** tied to timestamps
4. **Time-based seeking** with keyboard shortcuts

### Power Features
1. **Shareable filter/bookmark URLs**
2. **Pattern detection** and grouping
3. **Stack trace folding**
4. **Export/share functionality**

---

## References

- Datadog Log Explorer: https://docs.datadoghq.com/logs/explorer/
- Grafana Loki LogQL: https://grafana.com/docs/loki/latest/query/log_queries/
- Splunk Search Reference: https://docs.splunk.com
- Nielsen Norman Group Search UX: https://www.nngroup.com/articles/search-visible-and-simple/
- LogViewer (sevdokimov): https://github.com/sevdokimov/log-viewer
- Logdy: https://github.com/logdyhq/logdy-core
- klp: https://github.com/dloss/klp
- IntelliJ Stack Trace Analyzer: https://www.jetbrains.com/help/idea/analyzing-external-stacktraces.html
- Kibana Discover: https://www.elastic.co/docs/explore-analyze/discover
- Loggly Best Practices: https://www.loggly.com/blog/30-best-practices-logging-scale/
