# 🍿 Jellyfin Remote for macOS

<p align="center">
  <img src="Resources/AppIcon.icns" width="128" height="128" alt="Jellyfin Remote Logo">
</p>

<p align="center">
  <b>A lightweight, zero-dependency macOS Menu Bar utility to remotely control Jellyfin in Safari from your iPhone.</b>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-14.0%2B-blue?logo=apple" alt="macOS 14+">
  <img src="https://img.shields.io/badge/Swift-5.9%2B-orange?logo=swift" alt="Swift">
  <img src="https://img.shields.io/badge/Architecture-Universal%20(Apple%20Silicon%20%2B%20Intel)-purple" alt="Universal">
  <img src="https://img.shields.io/badge/License-MIT-green" alt="MIT License">
</p>

---

## ✨ Features

- 📱 **Zero iPhone Apps Needed:** Works directly in Safari on iOS as a responsive, thumb-friendly web app.
- 🍿 **macOS Menu Bar Resident:** Runs discreetly in your status bar (`NSStatusItem`) with zero Dock clutter.
- ⚡️ **Instant QR Pairing:** Built-in QR-code generator to connect your phone in 1 second.
- ⚙️ **Configurable Port:** Change the port on the fly with live socket restart and port conflict handling.
- 🎯 **Smart Tab Targeting:** Automatically routes commands to the active Jellyfin tab across multiple Safari windows.
- 📊 **Bidirectional Status:** Live progress bar, playback timer, and movie title feedback.
- ⌨️ **Quick Search:** Type search queries with your phone's native keyboard straight into Jellyfin.
- 🕹 **Thumb-Zone D-Pad:** Navigation optimized for one-handed thumb control.
- 🪶 **Ultra Lightweight:** Only ~2.6 MB (Zero third-party dependencies, built with pure `Network.framework` & `AppKit`).

---

## 🚀 Quick Start & Installation

### Option 1: Download Pre-built DMG
1. Download the latest `JellyfinRemote-vX.X.X.dmg` from the [Releases](https://github.com/your-username/JellyfinRemote/releases) page.
2. Open the DMG and drag **JellyfinRemote.app** into your **Applications** folder.
3. Launch `JellyfinRemote` from Applications.
4. Click the 🍿 icon in your Menu Bar, select **"Show QR Code"**, and scan it with your iPhone camera.

> **Note for macOS Gatekeeper:**
> Since this open-source build is ad-hoc signed, if macOS blocks launching on first run, run this in Terminal:
> ```bash
> xattr -cr /Applications/JellyfinRemote.app
> ```

---

## ⚙️ Prerequisites (Safari Setup on Mac)

To allow JellyfinRemote to communicate with Safari:
1. Open **Safari -> Settings -> Advanced** and check **"Show features for web developers"**.
2. In the menu bar, click **Develop -> Allow JavaScript from Apple Events**.
3. On first command from your phone, click **Allow** when macOS asks for Automation permissions.

---

## 🛠 Building from Source

```bash
# Clone the repository
git clone https://github.com/your-username/JellyfinRemote.git
cd JellyfinRemote

# Build standalone .app and .dmg installer
chmod +x scripts/*.sh
./scripts/build_dmg.sh

The output .dmg installer will be located in the dist/ folder.
🏛 Architecture
code
Code
[ iPhone Safari Web UI ]
          │
          ▼ (HTTP / JSON LAN socket)
[ WebServer.swift (Network.framework) ]
          │
          ▼ (Internal Controller)
[ SafariController.swift ]
          │
          ▼ (AppleScript / JXA DOM Event Dispatcher)
[ Safari Browser (Jellyfin Web Client) ]
📄 License
This project is licensed under the MIT License - see the LICENSE file for details.
code
Code
---