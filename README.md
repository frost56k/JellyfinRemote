# Jellyfin Remote for macOS

A lightweight macOS menu-bar application that turns Safari into a living-room media interface. Control Jellyfin from an iPhone browser or from a supported Bluetooth remote, including a Chromecast G9N9N BLE remote. The app bridges both inputs to Safari, with service-aware navigation for Jellyfin and YouTube Leanback.

<p align="center">
  <img src="Resources/AppIcon.png" width="112" height="112" alt="Jellyfin Remote app icon">
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-13.0%2B-blue?logo=apple" alt="macOS 13 or later">
  <img src="https://img.shields.io/badge/Swift-5.9%2B-orange?logo=swift" alt="Swift 5.9 or later">
  <img src="https://img.shields.io/badge/Apple%20Silicon%20%2B%20Intel-Universal-purple" alt="Universal binary">
  <img src="https://img.shields.io/badge/License-MIT-green" alt="MIT License">
</p>

## What it does

- **iPhone Web Remote:** Open the remote in iPhone Safari—no iOS app is required. Use the on-screen D-Pad, playback and volume controls, shortcuts, and search input. Pair quickly using the menu-bar app's QR code.
- **Bluetooth remote input:** Optionally listen for the Chromecast G9N9N BLE remote, identified by USB/Bluetooth HID vendor ID `0x18D1` and product ID `0x9450`.
- **Hardware button remapping:** The physical remote's **Netflix** button opens the Jellyfin web client; its **YouTube** button opens the YouTube Leanback TV interface at `https://www.youtube.com/tv#/`.
- **Power-button safety:** The Power button is intentionally not mapped to a Safari command; the feature is designed to neutralize it and avoid accidental lock/sleep actions on a headless or HTPC Mac mini. App-level handling cannot guarantee suppression of macOS-wide behavior on every device or OS. Do not use the Power button as a test. See [Power-button safety](#power-button-safety).
- **Service-aware D-Pad:** Jellyfin receives DOM `KeyboardEvent` navigation events in the page. YouTube Leanback receives key codes through System Events, which better matches the TV interface's expected remote input.
- **In-page volume control:** Volume is changed directly on Safari's active HTML video element. This bypasses the macOS HDMI output-volume lock that may appear as a missing volume value (for example, `-1700`) on HDMI/PCM setups. A persistent volume listener counters YouTube ad transitions that try to reset the selected player volume.
- **Safari TV mode:** A persistent Safari `CustomUserAgent` configures the Leanback user-agent used by YouTube TV.
- **Menu-bar utility:** Runs as a menu-bar app with QR pairing and configuration, without requiring a separate iPhone app.

## Requirements

- A Mac running macOS 13 Ventura or later (confirm the deployment target of the exact build you use).
- Safari, with a Jellyfin server reachable from the Mac for Jellyfin playback.
- An iPhone on a network that can reach the Mac for Web Remote control.
- Optional: a paired Chromecast G9N9N BLE remote (`VID 0x18D1`, `PID 0x9450`). Bluetooth support and macOS permissions are required for this input path.
- Xcode Command Line Tools / Swift toolchain to build from source.

## Installation

### Install a release build

1. Download the latest `JellyfinRemote-vX.Y.Z.dmg` from [GitHub Releases](https://github.com/frost56k/JellyfinRemote/releases).
2. Open the disk image and drag `JellyfinRemote.app` into `/Applications`.
3. Launch the app from `/Applications`. If macOS asks whether to open the app, review the prompt and approve only if you trust the build source.
4. Open the Jellyfin menu-bar item and choose **Show iPhone QR Code** (wording may vary by release). Scan the code with the iPhone camera and open the displayed address in Safari.
5. Pair the BLE remote in macOS Bluetooth settings. In Jellyfin Remote, explicitly enable the Bluetooth remote listener if the installed build offers the toggle.

The iPhone and Mac must be able to communicate over the local network. Do not expose the remote's HTTP port to the public Internet. If the Mac firewall prompts about incoming connections, allow the app only on the trusted network where you intend to use it.

### First-run Safari setup

Safari automation and page JavaScript execution must be enabled for the controls that use them:

1. In Safari, open **Safari → Settings → Advanced** and enable the developer features option (the exact label depends on Safari version).
2. From Safari's **Develop** menu, enable **Allow JavaScript from Apple Events**.
3. Start a Jellyfin control action and approve macOS's Automation prompt allowing **JellyfinRemote** to control **Safari**.
4. If YouTube navigation is dispatched with System Events, approve the corresponding macOS Automation request when prompted. On some macOS versions, the host app may also need to be allowed in **Privacy & Security → Accessibility**. Grant only permissions actually requested by the installed build.

macOS permission names and prompts can vary by version and app signature. If permissions were denied or the app was replaced with a newly signed build, review **System Settings → Privacy & Security** and restart Jellyfin Remote after changing access.

## Chromecast BLE remote and permissions

1. Pair the remote with the Mac using **System Settings → Bluetooth**.
2. In the app, enable the Bluetooth remote listener. Permission requests should follow an explicit user action.
3. Grant **Input Monitoring** to **JellyfinRemote** when macOS requests it. The permission belongs to the application: granting it to Terminal or a diagnostic utility does not grant it to Jellyfin Remote.
4. If the permission prompt does not appear, inspect **System Settings → Privacy & Security → Input Monitoring**, enable Jellyfin Remote, then quit and reopen the app.
5. Confirm the remote is connected and test only ordinary navigation and playback buttons. Avoid Power-button testing; see the safety note below.

The supported device is matched by VID/PID. Other remotes, button layouts, HID usages, and button behavior are not guaranteed. Check the app's current mapping before assuming another device is compatible.

### Power-button safety

The application mapping deliberately has no Safari action for the remote's Power button; its intent is to neutralize that input within Jellyfin Remote so an accidental press cannot become a media-navigation command. macOS may handle a physical power-button event independently of an app's passive HID listener. Therefore, app-level no-op handling is **not a universal guarantee** that the operating system will suppress sleep, lock, or power behavior. Treat this as a safety feature, not a substitute for macOS power configuration or hardware-level event suppression. Do not press the button to verify it.

## Safari Leanback setup

YouTube Leanback expects a TV-style user-agent. Set Safari's persistent `CustomUserAgent` preference in Terminal:

```sh
defaults write com.apple.Safari CustomUserAgent '"Mozilla/5.0 (PS4; Leanback Shell) Cobalt/26.lts.0-qa; compatible;"'
```

Then quit and reopen Safari, if needed, and use the remote's YouTube button to open `https://www.youtube.com/tv#/`. The preference is Safari-wide and can affect ordinary websites in other tabs, not only YouTube. If you previously had a custom value, save it before changing the setting and restore that original value when finished. To remove the override and return to Safari's default user-agent behavior (only if there was no pre-existing custom value), run:

```sh
defaults delete com.apple.Safari CustomUserAgent
```

YouTube may change its TV interface or supported user-agent behavior over time. If Leanback stops loading, first check the current Safari preference, restart Safari, and review the URL/interface; do not assume the web client is broken.

## Volume and HDMI audio behavior

On some macOS HDMI audio routes, hardware output volume is fixed and the system volume query can return a missing-value error such as `-1700`. Jellyfin Remote manages volume in the browser instead: it reads and adjusts the active `<video>` element's `volume` property (and mute state) in Safari. This changes that web video only; it does not change macOS output volume or the volume of other applications.

YouTube may replace or reset the player volume across ad transitions. The remote's persistent volume listener reapplies the chosen in-page level when such a reset is detected. Actual behavior depends on YouTube's current page/player implementation and the selected audio route. Validate it with the target Mac, display, and playback configuration.

## Using the remote

- Keep Safari open with Jellyfin loaded and signed in to your server. The iPhone remote sends commands to the Mac, and the Mac drives the relevant Safari page.
- Scan the QR code from the same trusted LAN. If the address does not load, check that the phone and Mac are on reachable networks and that the app is running and listening on its configured port.
- Use the physical **Netflix** button for Jellyfin and **YouTube** for YouTube Leanback.
- D-Pad dispatch is service-specific: Jellyfin uses page-level DOM keyboard events; YouTube Leanback uses System Events key codes.
- Use the in-browser volume controls for HDMI output routes where the macOS system volume is locked.

## Build from source

```bash
git clone https://github.com/frost56k/JellyfinRemote.git
cd JellyfinRemote

# Ensure the repository build scripts are executable
chmod +x scripts/*.sh

# Build the macOS app and package the DMG
./scripts/build_dmg.sh
```

The project is a Swift Package Manager app. For an app-only build, use the repository's build script:

```bash
./scripts/build_app.sh
```

The scripts require macOS build tools such as `swift`, `lipo`, `sips`, `iconutil`, `codesign`, and `hdiutil` for the DMG workflow. A universal build combines `arm64` and `x86_64` products when supported by the current script/toolchain. The output locations and versioned DMG name are defined by the scripts; check them before distributing. Locally generated builds may be ad-hoc signed and are not automatically notarized. For release distribution, use the project's release process and independently verify the artifact, signature, architectures, permissions, and target macOS version.

## Architecture

```text
┌─────────────────────┐  HTTP / JSON   ┌──────────────────┐
│ iPhone Web Remote   │ ──────────────>│ WebServer        │ ──┐
│ (Safari browser UI) │                └──────────────────┘   │
└─────────────────────┘                                       │
                                                               ├──> ┌──────────────────┐
┌─────────────────────┐  BLE / HID     ┌──────────────────┐   │    │ SafariController │
│ Chromecast G9N9N    │ ──────────────>│ BluetoothRemote  │ ──┘    └────────┬─────────┘
│ remote              │                │ Controller       │                 │
│ VID 0x18D1 / PID 9450│               └──────────────────┘                 ▼
└─────────────────────┘                                          ┌────────────────────┐
                                                                 │ Safari             │
                                                                 │ Jellyfin / YouTube │
                                                                 │ Leanback           │
                                                                 └────────────────────┘
```

The iPhone Web UI sends HTTP/JSON commands to `WebServer`; the BLE remote sends HID events to `BluetoothRemoteController`. Both routes converge on `SafariController`, which applies service-specific key dispatch and browser-side media operations in Safari.

## Troubleshooting

- **iPhone cannot connect:** Confirm Jellyfin Remote is running, the displayed address/port is current, the phone can reach the Mac over the LAN, and the firewall allows the app on that network.
- **Safari commands do nothing:** Enable **Allow JavaScript from Apple Events**, approve Automation access to Safari, and make sure a Jellyfin page is open and signed in.
- **YouTube D-Pad does not navigate:** Confirm the YouTube Leanback URL is active, Safari's `CustomUserAgent` is set as intended, System Events automation is approved if requested, and Safari has been restarted after changing the preference.
- **Bluetooth remote is not detected:** Confirm pairing, the supported VID/PID, the app's Bluetooth toggle, and Jellyfin Remote's Input Monitoring permission. Restart the app after permission changes.
- **Volume keys do not change HDMI system volume:** This is expected on fixed-volume HDMI/PCM output. Use the in-page volume control; it affects the Safari video element, not macOS or other apps.
- **Permission prompts recur:** macOS may reassess TCC permissions after an application update, replacement, or signature change. Recheck Privacy & Security settings and approve only the required permissions.

## Security and limitations

- Treat the iPhone remote as a trusted-LAN service. Do not forward its port from a router or expose it to untrusted networks unless you have separately secured and reviewed that deployment.
- Safari Automation, Input Monitoring, and any requested Accessibility access are powerful permissions. Grant them only to a trusted build of Jellyfin Remote.
- HID mappings are specific to supported controls on the identified remote. Do not assume unsupported buttons are intercepted or that the app can suppress macOS-wide system actions.
- YouTube, Safari, and macOS behavior can change; validate the setup on the target versions before relying on it in a headless installation.

## License

Distributed under the MIT License. See [`LICENSE`](LICENSE) for details.
