import Cocoa

public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var statusMenuItem: NSMenuItem!
    private var urlMenuItem: NSMenuItem!
    private var launchAtLoginMenuItem: NSMenuItem!
    
    public func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        setupServerCallbacks()
        WebServer.shared.start()
    }
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.title = "🍿"
            button.toolTip = "Jellyfin Remote Control"
        }
        
        let menu = NSMenu()
        
        let titleItem = NSMenuItem(title: "🍿 Jellyfin Remote v2.0", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        
        menu.addItem(NSMenuItem.separator())
        
        statusMenuItem = NSMenuItem(title: "🟢 Status: Starting...", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)
        
        urlMenuItem = NSMenuItem(title: "🌐 Address: Resolving...", action: nil, keyEquivalent: "")
        urlMenuItem.isEnabled = false
        menu.addItem(urlMenuItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let qrItem = NSMenuItem(title: "📱 Show iPhone QR Code...", action: #selector(showQRCode), keyEquivalent: "q")
        qrItem.target = self
        menu.addItem(qrItem)
        
        let portItem = NSMenuItem(title: "⚙️ Change Port...", action: #selector(changePortDialog), keyEquivalent: "p")
        portItem.target = self
        menu.addItem(portItem)
        
        let restartItem = NSMenuItem(title: "🔄 Restart Server", action: #selector(restartServer), keyEquivalent: "r")
        restartItem.target = self
        menu.addItem(restartItem)
        
        menu.addItem(NSMenuItem.separator())
        
        launchAtLoginMenuItem = NSMenuItem(title: "🚀 Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchAtLoginMenuItem.target = self
        updateLaunchAtLoginState()
        menu.addItem(launchAtLoginMenuItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "❌ Quit Jellyfin Remote", action: #selector(quitApp), keyEquivalent: "w")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem.menu = menu
    }
    
    private func setupServerCallbacks() {
        WebServer.shared.onStateChange = { [weak self] isRunning, message in
            guard let self = self else { return }
            if isRunning {
                self.statusMenuItem.title = "🟢 Status: Running"
                self.urlMenuItem.title = "🌐 \(message)"
            } else {
                self.statusMenuItem.title = "🔴 Status: Error"
                self.urlMenuItem.title = "⚠️ \(message)"
            }
        }
    }
    
    @objc private func showQRCode() {
        let ip = getIPAddress() ?? "localhost"
        let port = WebServer.shared.activePort
        let url = "http://\(ip):\(port)"
        QRCodeWindowController.shared.show(url: url)
    }
    
    @objc private func changePortDialog() {
        let alert = NSAlert()
        alert.messageText = "Change Web Server Port"
        alert.informativeText = "Enter a new port number (between 1024 and 65535).\nCurrent port: \(WebServer.shared.activePort)"
        alert.alertStyle = .informational
        
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        input.stringValue = "\(WebServer.shared.activePort)"
        alert.accessoryView = input
        
        alert.addButton(withTitle: "Apply")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            let text = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if let newPort = SettingsManager.shared.validatePort(text) {
                SettingsManager.shared.currentPort = newPort
                WebServer.shared.restart(port: newPort)
            } else {
                let errorAlert = NSAlert()
                errorAlert.messageText = "Invalid Port"
                errorAlert.informativeText = "The port must be an integer between 1024 and 65535."
                errorAlert.alertStyle = .warning
                errorAlert.runModal()
            }
        }
    }
    
    @objc private func restartServer() {
        WebServer.shared.restart()
    }
    
    @objc private func toggleLaunchAtLogin() {
        _ = SettingsManager.shared.toggleLaunchAtLogin()
        updateLaunchAtLoginState()
    }
    
    private func updateLaunchAtLoginState() {
        let isEnabled = SettingsManager.shared.isLaunchAtLoginEnabled
        launchAtLoginMenuItem.state = isEnabled ? .on : .off
    }
    
    @objc private func quitApp() {
        WebServer.shared.stop()
        NSApplication.shared.terminate(nil)
    }
}
