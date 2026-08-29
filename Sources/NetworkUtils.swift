import Foundation

/// Возвращает локальный IPv4-адрес Mac mini в сети Wi-Fi/Ethernet (en0/en1)
public func getIPAddress() -> String? {
    var address: String?
    var ifaddr: UnsafeMutablePointer<ifaddrs>?
    
    if getifaddrs(&ifaddr) == 0 {
        var ptr = ifaddr
        while ptr != nil {
            defer { ptr = ptr?.pointee.ifa_next }
            guard let interface = ptr?.pointee else { continue }
            let addrFamily = interface.ifa_addr.pointee.sa_family
            
            // Фильтруем IPv4 (AF_INET)
            if addrFamily == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)
                // en0 обычно Wi-Fi (или Ethernet на Mac mini), en1 - второй сетевой адаптер
                if name == "en0" || name == "en1" {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(
                        interface.ifa_addr,
                        socklen_t(interface.ifa_addr.pointee.sa_len),
                        &hostname,
                        socklen_t(hostname.count),
                        nil,
                        socklen_t(0),
                        NI_NUMERICHOST
                    )
                    let foundIP = String(cString: hostname)
                    // Исключаем петлевой адрес
                    if foundIP != "127.0.0.1" {
                        address = foundIP
                        break
                    }
                }
            }
        }
        freeifaddrs(ifaddr)
    }
    return address
}
