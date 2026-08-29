# 🍿 Jellyfin Remote for macOS

<p align="center">
  <img src="Resources/AppIcon.png" width="128" height="128" alt="Jellyfin Remote Logo">
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

## ✨ Key Features

- 📱 **Zero iPhone Apps Needed:** Works directly in mobile Safari with a responsive, haptic-enabled web remote.
- 🍿 **macOS Menu Bar Resident:** Lives quietly in your menu bar (`NSStatusItem`) with zero Dock clutter.
- ⚡️ **Instant QR Pairing:** Built-in QR-code generator to pair your iPhone in 1 second.
- ⚙️ **Configurable Port:** Change HTTP ports on the fly with automatic socket restarting.
- 🎯 **Smart Safari Tab Targeting:** Automatically locates and controls the active Jellyfin tab across windows.
- 📊 **Bidirectional Status:** Real-time playback timer, movie title, and progress bar feedback.
- ⌨️ **Quick Text Search:** Type search queries with your phone's native keyboard directly into Jellyfin.
- 🕹 **Thumb-Zone D-Pad:** Navigation layout optimized for one-handed thumb control on mobile devices.
- 🪶 **Ultra Lightweight:** Only ~2.6 MB (Universal Binary for Apple Silicon & Intel Haswell+).

---

## 🚀 Installation & Quick Start

### Option 1: Download Pre-built DMG
1. Download the latest `JellyfinRemote-vX.X.X.dmg` from the **[Releases](https://github.com/frost56k/JellyfinRemote/releases)** section.
2. Open the `.dmg` and drag **JellyfinRemote.app** into your **Applications** folder.
3. Launch `JellyfinRemote` from Applications.
4. Click the 🍿 icon in the macOS Menu Bar, select **"Show iPhone QR Code..."**, and scan it with your iPhone camera.

> **macOS Gatekeeper Note:**  
> If macOS displays a security prompt on first launch, open Terminal and run:
> ```bash
> xattr -cr /Applications/JellyfinRemote.app
> ```

---

## ⚙️ Safari Setup (One-time prerequisite)

To enable AppleScript JavaScript dispatching in Safari on macOS:
1. Open **Safari ➔ Settings (⌘,) ➔ Advanced** and check **"Show features for web developers"**.
2. In the top Safari menu, click **Develop ➔ Allow JavaScript from Apple Events** (ensure it is checked ✅).
3. On the first remote command, click **OK** when macOS asks for Automation permissions.

---

## 🛠 Building from Source

```bash
# Clone the repository
git clone https://github.com/frost56k/JellyfinRemote.git
cd JellyfinRemote

# Build standalone .app and .dmg installer
chmod +x scripts/*.sh
./scripts/build_dmg.sh
The compiled installer will be available at dist/JellyfinRemote-v2.0.0.dmg.
🏛 Architecture
code
Text
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
Distributed under the MIT License. See LICENSE for more information.
