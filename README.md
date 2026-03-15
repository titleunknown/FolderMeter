<p align="center">
  <img src="folder meter icon.png" alt="FolderMeter" width="128" />
</p>

<h1 align="center">FolderMeter</h1>

<p align="center">
  A lightweight macOS menu bar app that monitors folder sizes in real time.<br/>
  Built for photographers using Capture One — works with any folder.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-14%2B-blue" />
  <img src="https://img.shields.io/badge/Swift-5.9-orange" />
  <img src="https://img.shields.io/badge/made%20by-FAINI%20MADE-black" />
</p>

<p align="center">
  <img src="Screenshot_FolderMeter.jpg" alt="FolderMeter screenshot" width="340" />
</p>

---

## Features

- **Live updates** — file system watcher fires the moment files change, no polling
- **Capture One session detection** — auto-detects Capture / Output / Trash / Selects structure
- **Generic folder mode** — works as a watcher for any folder
- **RAW & JPG counts** — tracks image file types separately across the whole session
- **Per-subfolder breakdown** — size bars, folder counts, file type stats per folder
- **CaptureOne folder excluded** — proxy caches and catalog files don't skew your numbers
- **Persistent** — remembers your folder across launches
- Menu bar only — no dock icon, no ⌘-Tab clutter

---

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15+

## Building

1. Clone the repo
2. Open `FolderMeter.xcodeproj` in Xcode
3. Set your development team in **Signing & Capabilities**
4. Add the entitlement `com.apple.security.files.user-selected.read-only`
5. Set deployment target to **macOS 14.0**
6. Build & Run (`⌘R`)

---

## Capture One Detection

Detects a Capture One session when the watched folder contains a `Capture` subfolder, or both `Output` + `Trash`. Once detected, named rows are shown with context-aware icons:

| Folder | Color | Notes |
|---|---|---|
| Capture | Orange | Shows RAW file count badge |
| Output | Blue | Shows JPG count and subfolder count |
| Trash | Red | |
| Selects | Green | |

The `CaptureOne` system folder (proxies, cache, catalog) is excluded from all file counts and size totals.

## RAW Formats Supported

`CR2 CR3 NEF ARW ORF RW2 DNG RAF 3FR FFF IIQ MRW NRW PEF RWL SR2 SRF X3F ERF RAW`

---

## Support

If you find FolderMeter useful, consider supporting development:

<p align="center">
  <a href="https://www.paypal.com/donate/?hosted_button_id=AEY7AC82BKH5C">
    <img src="https://img.shields.io/badge/Donate-PayPal-0070BA?style=for-the-badge&logo=paypal&logoColor=white" />
  </a>
  &nbsp;
  <a href="https://account.venmo.com/u/FAINI">
    <img src="https://img.shields.io/badge/Donate-Venmo-3D95CE?style=for-the-badge&logo=venmo&logoColor=white" />
  </a>
  &nbsp;
  <a href="https://buymeacoffee.com/fainimade">
    <img src="https://img.shields.io/badge/Buy_Me_a_Coffee-FFDD00?style=for-the-badge&logo=buy-me-a-coffee&logoColor=black" />
  </a>
</p>

---

<p align="center">
  Made by <a href="https://www.fainimade.com">FAINI MADE</a>
