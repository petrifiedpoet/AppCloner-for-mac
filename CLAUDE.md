# AppCloner-for-mac Developer Guide

## 🛠️ Build & Package Commands

To clean, compile, codesign, and package the application into a `.app` bundle and a `.dmg` installer:
```bash
./build.sh
```

## 🏗️ Architectural & Coding Rules

1. **Universal Binary Target**:
   - Both `libredirect.dylib` and the `AppCloner` swift application must compile for both `arm64` and `x86_64` to maintain compatibility on Intel and Apple Silicon Macs.
2. **Library Hooking Safety (Recursion Avoidance)**:
   - In `libredirect.m`, do NOT use standard logging functions (like `NSLog`, `printf`) inside POSIX hooked functions (`getpwuid` or `getpwuid_r`). These logging functions trigger lookup calls themselves, resulting in infinite recursion and crashing the app with SIGSEGV (exit code 139).
3. **Codesign Redirection (Ad-hoc signing)**:
   - When cloning any target app, `/usr/bin/codesign --force --deep --sign -` must be executed on the clone bundle. This removes the hardened runtime entitlement to allow `DYLD_INSERT_LIBRARIES` dylib injection.

## 📂 Directories & File Roles

- `AppCloner.swift`: SwiftUI UI application and cloning processor.
- `libredirect.m`: Objective-C dynamic library source code to hook file paths.
- `Info.plist`: Package info metadata template.
- `AppIcon.icns`: Application icon asset.
- `build.sh`: Shell script orchestrating the universal build and DMG creation.
- `README.md`: General user manual, architecture descriptions, and Gatekeeper bypass instructions.
- `CLAUDE.md`: Rulebook for developers and AI agents (this file).
