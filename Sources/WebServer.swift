import Foundation
import Network

@available(macOS 10.14, *)
public final class WebServer: @unchecked Sendable {
    public static let shared = WebServer()
    
    private var listener: NWListener?
    public private(set) var activePort: UInt16 = 9999
    public private(set) var isRunning: Bool = false
    
    public var onStateChange: ((Bool, String) -> Void)?
    
    public init() {}
    
    /// Запуск сервера на указанном порту
    public func start(port: UInt16? = nil) {
        let selectedPort = port ?? SettingsManager.shared.currentPort
        self.stop()
        
        do {
            let nwPort = NWEndpoint.Port(rawValue: selectedPort) ?? 9999
            listener = try NWListener(using: .tcp, on: nwPort)
            
            listener?.stateUpdateHandler = { [weak self] state in
                guard let self = self else { return }
                switch state {
                case .ready:
                    self.isRunning = true
                    self.activePort = selectedPort
                    let ip = getIPAddress() ?? "localhost"
                    let msg = "http://\(ip):\(selectedPort)"
                    print("🌐 Сервер готов: \(msg)")
                    self.onStateChange?(true, msg)
                case .failed(let error):
                    self.isRunning = false
                    print("❌ Ошибка слушателя на порту \(selectedPort): \(error)")
                    self.onStateChange?(false, "Порт \(selectedPort) недоступен: \(error.localizedDescription)")
                case .cancelled:
                    self.isRunning = false
                default:
                    break
                }
            }
            
            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection)
            }
            
            listener?.start(queue: .main)
        } catch {
            self.isRunning = false
            print("❌ Ошибка запуска сервера на порту \(selectedPort): \(error)")
            self.onStateChange?(false, "Ошибка: \(error.localizedDescription)")
        }
    }
    
    /// Остановка сервера
    public func stop() {
        if let l = listener {
            l.cancel()
            listener = nil
            isRunning = false
            print("🛑 Веб-сервер остановлен.")
        }
    }
    
    /// Перезапуск сервера (при смене порта или сбое)
    public func restart(port: UInt16? = nil) {
        stop()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.start(port: port)
        }
    }
    
    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .main)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16384) { [weak self] data, _, _, _ in
            guard let self = self, let data = data, let request = String(data: data, encoding: .utf8) else {
                connection.cancel()
                return
            }
            
            let response = self.routeRequest(request)
            let responseData = response.data(using: .utf8) ?? Data()
            
            connection.send(content: responseData, completion: .contentProcessed({ _ in
                connection.cancel()
            }))
        }
    }
    
    private func routeRequest(_ request: String) -> String {
        let lines = request.components(separatedBy: "\r\n")
        guard let firstLine = lines.first else { return http404() }
        let parts = firstLine.components(separatedBy: " ")
        guard parts.count >= 2 else { return http404() }
        let path = parts[1]
        
        if path.hasPrefix("/api/status") {
            let statusJSON = SafariController.getPlaybackStatus()
            return httpRawJSON(statusJSON)
        } else if path.hasPrefix("/api/command") {
            return handleAPICommand(path: path)
        } else {
            return http200HTML(HTMLContent.indexHTML)
        }
    }
    
    private func handleAPICommand(path: String) -> String {
        guard let urlComponents = URLComponents(string: path),
              let queryItems = urlComponents.queryItems,
              let cmd = queryItems.first(where: { $0.name == "cmd" })?.value else {
            return httpJSON(["status": "error", "message": "Missing cmd parameter"])
        }
        
        var resultMessage = "ok"
        
        switch cmd {
        case "reload":
            resultMessage = SafariController.reloadPage() ?? "reloaded"
        case "play_pause":
            resultMessage = SafariController.togglePlayPause() ?? "error"
        case "seek_forward":
            resultMessage = SafariController.seek(by: 10) ?? "error"
        case "seek_backward":
            resultMessage = SafariController.seek(by: -10) ?? "error"
        case "fullscreen":
            resultMessage = SafariController.toggleFullscreen() ?? "error"
        case "mute":
            resultMessage = SafariController.toggleMute() ?? "error"
        case "vol_up":
            resultMessage = SafariController.changeVolume(by: 0.1) ?? "error"
        case "vol_down":
            resultMessage = SafariController.changeVolume(by: -0.1) ?? "error"
        case "home":
            SafariController.goHome()
            resultMessage = "Navigated Home"
        case "movies":
            SafariController.goMovies()
            resultMessage = "Navigated Movies"
        case "series":
            SafariController.goSeries()
            resultMessage = "Navigated Series"
        case "search":
            SafariController.focusSearch()
            resultMessage = "Search focused"
        case "type_text":
            if let text = queryItems.first(where: { $0.name == "text" })?.value {
                resultMessage = SafariController.typeSearchText(text) ?? "typed"
            }
        case "focus_safari":
            SafariController.activateSafari()
            resultMessage = "Safari Focused"
        case "up":
            SafariController.sendKey(code: SafariController.KeyCode.up)
        case "down":
            SafariController.sendKey(code: SafariController.KeyCode.down)
        case "left":
            SafariController.sendKey(code: SafariController.KeyCode.left)
        case "right":
            SafariController.sendKey(code: SafariController.KeyCode.right)
        case "enter":
            SafariController.sendKey(code: SafariController.KeyCode.enter)
        case "escape":
            SafariController.sendKey(code: SafariController.KeyCode.escape)
        default:
            resultMessage = "unknown command"
        }
        
        return httpJSON(["status": "success", "result": resultMessage])
    }
    
    private func http200HTML(_ html: String) -> String {
        return "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nCache-Control: no-store\r\nContent-Length: \(html.utf8.count)\r\nConnection: close\r\n\r\n\(html)"
    }
    
    private func httpJSON(_ json: [String: Any]) -> String {
        let jsonData = (try? JSONSerialization.data(withJSONObject: json)) ?? Data()
        let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
        return httpRawJSON(jsonString)
    }
    
    private func httpRawJSON(_ jsonString: String) -> String {
        return "HTTP/1.1 200 OK\r\nContent-Type: application/json; charset=utf-8\r\nAccess-Control-Allow-Origin: *\r\nCache-Control: no-store\r\nContent-Length: \(jsonString.utf8.count)\r\nConnection: close\r\n\r\n\(jsonString)"
    }
    
    private func http404() -> String {
        return "HTTP/1.1 404 Not Found\r\nConnection: close\r\n\r\n"
    }
}
