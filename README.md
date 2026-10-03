# Attendance for macOS 🎓📊

A native macOS menu-bar and dashboard attendance companion for college students, written in **Swift & SwiftUI**. Based on the Android college attendance client, this application monitors your attendance in real-time, displays your overall percentage directly in the macOS menu bar, alerts you when your percentage dips below target thresholds, and offers an interactive **Bunk & Recovery Simulator**.

---

## ✨ Features

- **Native macOS Menu-Bar App (`MenuBarExtra`)**:
  - Live overall percentage displayed directly in your menu bar (e.g. `84.5%` with status color dot).
  - Compact, high-density popup window with circular gauge, today's period dots (`P`, `A`, `H`, `L`), ongoing class indicator, and quick subject stats.
  - Quick action menu to switch accounts, refresh, open dashboard, or modify preferences.

- **Full Dashboard Window**:
  - **Overview**: Circular progress gauge, attendance standing banner, key metrics (Attended, Total Held, Periods can skip / Periods needed), today's marked timeline, and class schedule.
  - **Subjects**: Complete subject-by-subject breakdown with progress bars, threshold target markers, bunk estimators, and per-subject "+1 / -1" interactive simulation.
  - **Timetable**: Weekly class timetable (Monday–Sunday) with ongoing class badges and a searchable Faculty Directory with direct email/phone copy actions.
  - **Attendance Grid**: Full Register Matrix table with frozen subject column, scrollable date headers, and color-coded cells (`P`, `A`, `H`, `L`, `%`).
  - **Bunk Simulator**: What-If calculation playground to simulate skipping or attending upcoming classes and evaluate the resulting percentage and recovery requirements.
  - **Settings**: Attendance target threshold slider (50% – 95%), sync interval (15m, 30m, 1h, 3h, 6h), college active hours toggle, appearance theme (System, Light, Dark), and notification test.

- **Security & Privacy**:
  - Student portal credentials (Student ID and password) are securely stored in the **macOS Keychain** using Apple's `Security.framework`.

- **Multi-Account Support**:
  - Manage multiple student accounts simultaneously. Switch active accounts in one click from the menu bar or settings, and set custom account aliases.

- **Background Synchronization**:
  - Periodic background polling without waking up your screen or draining battery.
  - Automatic active college hours filter (9 AM – 4 PM) so sync cycles run only during class periods.

- **Native macOS Notifications**:
  - Alerts powered by `UserNotifications.framework` trigger automatically if overall attendance crosses below the configured threshold.

- **Offline & Cache-First**:
  - Full local cache storage ensures instant launch even without an active internet connection.

---

## 🛠️ Technology Stack & Architecture

- **Language**: Swift 5.9 / Swift 6
- **UI Framework**: SwiftUI (macOS 13+)
- **Menu Bar**: `MenuBarExtra` with `.window` style
- **Security**: macOS Keychain Services (`Security.framework`)
- **Networking**: `URLSession` async/await with double-JSON-encoded payload decoding fallback
- **Notifications**: `UserNotifications.framework`
- **Architecture**: MVVM with reactive `@MainActor` state management

```
Attendance Mac/
├── Package.swift                               # SwiftPM manifest
├── AttendanceMac.xcodeproj/                    # Standard Xcode project
│   └── project.pbxproj
├── Sources/
│   └── AttendanceMac/
│       ├── App/
│       │   ├── AttendanceMacApp.swift          # Main entry (@main), MenuBarExtra & Window
│       │   └── WindowController.swift          # AppKit NSWindowController presentation helper
│       ├── Models/
│       │   ├── AttendanceModels.swift          # API response, timetable, and calculation models
│       │   ├── AttendanceStatus.swift          # Period statuses (P, A, H, L) & badges
│       │   └── UserAccount.swift               # Multi-account data structure
│       ├── Services/
│       │   ├── AttendanceAPIService.swift      # URLSession async client
│       │   ├── KeychainService.swift           # macOS Keychain storage
│       │   ├── StorageService.swift            # UserDefaults & local cache
│       │   ├── NotificationManager.swift       # UserNotifications wrapper
│       │   └── BackgroundSyncManager.swift     # Periodic background synchronization
│       ├── ViewModels/
│       │   └── AttendanceViewModel.swift       # Central @MainActor ObservableObject
│       ├── Views/
│       │   ├── Components/                     # Gauges, status badges, metric cards, blur views
│       │   ├── MenuBar/                        # Status bar label & popup content views
│       │   ├── Dashboard/                      # Overview, Subjects, Timetable, Grid, Simulator, Settings
│       │   └── Login/                          # Student authentication view
│       └── Resources/
│           ├── Assets.xcassets/                # App icon & image catalog
│           └── Info.plist                      # Application metadata
└── README.md
```

---

## 🚀 How to Run & Build

### One-Click Terminal Run (Quickest)
Inside the `Attendance Mac` directory:
```bash
./run_mac_app.sh
```
This builds the native macOS application bundle and launches it straight into your Menu Bar!

### In Xcode (Recommended for Development)
1. Open the project in Xcode:
   ```bash
   open "Attendance Mac/AttendanceMac.xcodeproj"
   ```
2. Select the target **AttendanceMac** > **My Mac** in the scheme selector.
3. Press **Run** (`⌘R`).

### From Terminal (Swift Package Manager)
Build and run using Swift Package Manager:
```bash
cd "Attendance Mac"
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run
```

Or build a release binary:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build -c release
```

---

## ⌨️ Keyboard Shortcuts

| Shortcut | Action |
| :--- | :--- |
| `⌘R` | Refresh attendance data |
| `⌘D` | Open Dashboard window |
| `⌘,` | Open Preferences / Settings |
| `⌘Q` | Quit application |

---

## 📄 License
Created for personal academic tracking. Compatible with the college attendance REST API service.
