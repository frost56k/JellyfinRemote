import Foundation
import ServiceManagement

public final class SettingsManager {
    public static let shared = SettingsManager()
    
    private let portKey = "server_custom_port"
    private let defaultPort: UInt16 = 9999
    
    private init() {}
    
    /// Текущий настроенный порт
    public var currentPort: UInt16 {
        get {
            let port = UserDefaults.standard.integer(forKey: portKey)
            if port >= 1024 && port <= 65535 {
                return UInt16(port)
            }
            return defaultPort
        }
        set {
            UserDefaults.standard.set(Int(newValue), forKey: portKey)
        }
    }
    
    /// Валидация вводимого порта
    public func validatePort(_ portString: String) -> UInt16? {
        guard let port = UInt16(portString), port >= 1024 && port <= 65535 else {
            return nil
        }
        return port
    }
    
    /// Статус автозапуска при входе в систему
    public var isLaunchAtLoginEnabled: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }
    
    /// Переключение автозапуска
    public func toggleLaunchAtLogin() -> Bool {
        if #available(macOS 13.0, *) {
            do {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                    return false
                } else {
                    try SMAppService.mainApp.register()
                    return true
                }
            } catch {
                print("❌ Ошибка настройки автозапуска: \(error)")
            }
        }
        return false
    }
}
