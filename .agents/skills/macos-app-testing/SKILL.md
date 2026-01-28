# macOS App Testing Skill

Testing macOS apps physically by building and running them to verify functionality.

## Build and Run Workflow

### 1. Generate Project
```bash
./build.sh
```

### 2. Build the App
```bash
xcodebuild -project adb-assistant.xcodeproj -scheme adb-assistant -configuration Debug build
```

### 3. Find the Built App
```bash
ls ~/Library/Developer/Xcode/DerivedData/adb-assistant-*/Build/Products/Debug/adb-assistant.app
```

### 4. Launch the App
```bash
open ~/Library/Developer/Xcode/DerivedData/adb-assistant-*/Build/Products/Debug/adb-assistant.app
```

Or launch from build:
```bash
xcodebuild -project adb-assistant.xcodeproj -scheme adb-assistant -configuration Debug run
```

## Testing Checklist

### Launch Tests
- [ ] App launches without crash
- [ ] Main window appears
- [ ] No console errors on launch
- [ ] Menu bar is populated

### Core Functionality
- [ ] Device detection works
- [ ] Log streaming starts automatically
- [ ] UI is responsive
- [ ] No beach ball during high log volume

### UI Elements
- [ ] Toolbar buttons work
- [ ] Filter bar is accessible
- [ ] Log list scrolls smoothly
- [ ] Status bar shows correct info

## Debugging Crashes

### Check Console Logs
```bash
# Stream logs from the app
log stream --predicate 'process == "adb-assistant"' --level debug
```

### Check Crash Reports
```bash
ls ~/Library/Logs/DiagnosticReports/ | grep adb-assistant
```

### Run with Debugger
```bash
lldb ~/Library/Developer/Xcode/DerivedData/adb-assistant-*/Build/Products/Debug/adb-assistant.app/Contents/MacOS/adb-assistant
(lldb) run
```

## Common Issues

### "App is damaged" Warning
```bash
xattr -cr /path/to/adb-assistant.app
```

### Code Signing Issues
```bash
codesign --force --deep --sign - /path/to/adb-assistant.app
```

### Permission Issues
```bash
# Grant accessibility permissions if needed
# System Settings > Privacy & Security > Accessibility
```

## Automated UI Testing (Optional)

Use XCTest UI testing framework:
```swift
import XCTest

class ADBAssistantUITests: XCTestCase {
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.windows.firstMatch.exists)
    }
}
```

## Best Practices

1. **Always test on real hardware** - Simulators don't catch all issues
2. **Test with real ADB device** - Many features require actual Android device
3. **Monitor CPU/Memory** - Use Activity Monitor during testing
4. **Test edge cases** - Empty states, error conditions, high load
5. **Clean build between tests** - `rm -rf ~/Library/Developer/Xcode/DerivedData/adb-assistant-*`
