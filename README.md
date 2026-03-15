# FolderMeter

A macOS 13+ menu bar app that monitors folder sizes in real time.

## Features

- **Live updates** via file system watching — no polling
- **Auto-detects Capture One sessions** (Capture / Output / Trash / Selects)
- **Falls back to generic mode** for any folder
- Shows total size in the menu bar
- Dropdown shows per-subfolder breakdown with proportional bars
- RAW file count (CR2, CR3, NEF, ARW, DNG, and 15+ more formats)
- "Open in Finder" shortcut
- Persists your selected folder across launches

## Setup in Xcode

1. Create a new **macOS App** project in Xcode
2. Set **Deployment Target** to macOS 13.0
3. Replace/add all `.swift` files from this folder
4. Replace `Info.plist` (the `LSUIElement = true` key hides the dock icon)
5. In **Signing & Capabilities**, add:
   - `com.apple.security.files.user-selected.read-only` (to read folder sizes)
6. Build & Run (`Cmd+R`)

## Xcode Project Settings

| Setting | Value |
|---|---|
| Deployment Target | macOS 13.0 |
| App Category | Utilities |
| Bundle Identifier | com.fainimade.foldermeter |
| LSUIElement | YES (menu bar only, no dock icon) |

## Capture One Detection

The app detects a Capture One session if the folder contains any of:
- A `Capture` subfolder
- Both `Output` + `Trash` subfolders

Once detected, it shows named rows with context-aware icons and colors:
- 🔶 **Capture** — orange (RAW files)
- 🔵 **Output** — blue
- 🔴 **Trash** — red  
- 🟢 **Selects** — green

## File Extensions Counted as RAW

`raw cr2 cr3 nef arw orf rw2 dng raf 3fr fff iiq mrw nrw pef rwl sr2 srf x3f erf`
