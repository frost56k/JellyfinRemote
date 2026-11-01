import AppKit
import CoreFoundation
import IOKit.hid

/// Пассивный слушатель Chromecast Bluetooth Remote (VID 18D1 / PID 9450).
/// Не захватывает устройство и не генерирует системные нажатия клавиш.
public final class BluetoothRemoteController {
    public static let shared = BluetoothRemoteController()

    public enum State: Equatable {
        case stopped
        case waitingForPermission
        case listening(connected: Bool)
        case failed(String)

        public var menuTitle: String {
            switch self {
            case .stopped:
                return "Пульт Bluetooth: выключен"
            case .waitingForPermission:
                return "Пульт Bluetooth: требуется разрешение ввода"
            case .listening(true):
                return "Пульт Bluetooth: подключён"
            case .listening(false):
                return "Пульт Bluetooth: ожидает пульт"
            case .failed(let message):
                return "Пульт Bluetooth: ошибка — \(message)"
            }
        }
    }

    public var onStateChange: ((State) -> Void)?

    public private(set) var state: State = .stopped {
        didSet {
            onStateChange?(state)
        }
    }

    private let vendorID = 0x18D1
    private let productID = 0x9450

    private var manager: IOHIDManager?
    private var scheduledRunLoop: CFRunLoop?
    private var isOpen = false

    private var matchedDevices = Set<ObjectIdentifier>()
    private var pressed = Set<PressedUsage>()

    private struct PressedUsage: Hashable {
        let device: ObjectIdentifier
        let usage: UInt32
    }

    private init() {}

    /// Запрашивает разрешение только после явного действия пользователя.
    @discardableResult
    public func requestPermission() -> Bool {
        guard #available(macOS 10.15, *) else {
            return true
        }

        let requestType = kIOHIDRequestTypeListenEvent

        switch IOHIDCheckAccess(requestType) {
        case kIOHIDAccessTypeGranted:
            return true

        case kIOHIDAccessTypeDenied:
            _ = IOHIDRequestAccess(requestType)
            return false

        case kIOHIDAccessTypeUnknown:
            return IOHIDRequestAccess(requestType)

        default:
            return false
        }
    }

    /// Запускает прослушивание. Повторный вызов ничего не меняет.
    public func start() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.start()
            }
            return
        }

        guard manager == nil else {
            return
        }

        guard #available(macOS 10.15, *),
              IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted else {
            state = .waitingForPermission
            return
        }

        guard let mainRunLoop = CFRunLoopGetMain() else {
            state = .failed("основной CFRunLoop недоступен")
            return
        }

        let newManager = IOHIDManagerCreate(
            kCFAllocatorDefault,
            IOOptionBits(kIOHIDOptionsTypeNone)
        )
        manager = newManager

        let matching: [String: Any] = [
            kIOHIDVendorIDKey as String: vendorID,
            kIOHIDProductIDKey as String: productID
        ]

        IOHIDManagerSetDeviceMatching(newManager, matching as CFDictionary)

        let context = Unmanaged.passUnretained(self).toOpaque()

        IOHIDManagerRegisterDeviceMatchingCallback(
            newManager,
            Self.deviceMatched,
            context
        )
        IOHIDManagerRegisterDeviceRemovalCallback(
            newManager,
            Self.deviceRemoved,
            context
        )
        IOHIDManagerRegisterInputValueCallback(
            newManager,
            Self.valueReceived,
            context
        )

        scheduledRunLoop = mainRunLoop

        IOHIDManagerScheduleWithRunLoop(
            newManager,
            mainRunLoop,
            CFRunLoopMode.commonModes.rawValue
        )

        let result = IOHIDManagerOpen(
            newManager,
            IOOptionBits(kIOHIDOptionsTypeSeizeDevice)
        )

        guard result == kIOReturnSuccess else {
            manager = nil
            cleanup(newManager)
            matchedDevices.removeAll()
            pressed.removeAll()
            state = .failed("IOHIDManagerOpen: \(Self.statusCode(result))")
            return
        }

        isOpen = true
        state = .listening(connected: !matchedDevices.isEmpty)
    }

    /// Останавливает прослушивание.
    public func stop() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.stop()
            }
            return
        }

        guard let activeManager = manager else {
            pressed.removeAll()
            matchedDevices.removeAll()
            state = .stopped
            return
        }

        manager = nil
        cleanup(activeManager)
        pressed.removeAll()
        matchedDevices.removeAll()
        state = .stopped
    }

    private func cleanup(_ activeManager: IOHIDManager) {
        let context = Unmanaged.passUnretained(self).toOpaque()

        IOHIDManagerRegisterDeviceMatchingCallback(activeManager, nil, context)
        IOHIDManagerRegisterDeviceRemovalCallback(activeManager, nil, context)
        IOHIDManagerRegisterInputValueCallback(activeManager, nil, context)

        if let scheduledRunLoop {
            IOHIDManagerUnscheduleFromRunLoop(
                activeManager,
                scheduledRunLoop,
                CFRunLoopMode.commonModes.rawValue
            )
            self.scheduledRunLoop = nil
        }

        if isOpen {
            IOHIDManagerClose(
                activeManager,
                IOOptionBits(kIOHIDOptionsTypeNone)
            )
            isOpen = false
        }
    }

    private func didMatch(_ identifier: ObjectIdentifier, result: IOReturn) {
        guard manager != nil else {
            return
        }

        guard result == kIOReturnSuccess else {
            state = .failed("обнаружение: \(Self.statusCode(result))")
            return
        }

        matchedDevices.insert(identifier)
        state = .listening(connected: true)
    }

    private func didRemove(_ identifier: ObjectIdentifier, result: IOReturn) {
        guard manager != nil else {
            return
        }

        matchedDevices.remove(identifier)
        pressed = pressed.filter { $0.device != identifier }

        if result != kIOReturnSuccess {
            state = .failed("отключение: \(Self.statusCode(result))")
        } else {
            state = .listening(connected: !matchedDevices.isEmpty)
        }
    }

    private func didReceive(
        page: UInt32,
        usage: UInt32,
        value: Int,
        device: ObjectIdentifier,
        result: IOReturn
    ) {
        guard result == kIOReturnSuccess else {
            state = .failed("чтение ввода: \(Self.statusCode(result))")
            return
        }

        // Consumer Page (0x0C); пропускаем только назначенные кнопки.
        guard manager != nil,
              page == 0x000C,
              [
                  0x0041, // Select / OK
                  0x0042, // Up
                  0x0043, // Down
                  0x0044, // Left
                  0x0045, // Right
                  0x00E9, // Volume Up
                  0x00EA, // Volume Down
                  0x00E2, // Mute
                  0x0077, // YouTube
                  0x0078, // Netflix / Jellyfin
                  0x0223, // Home
                  0x0224  // Back
              ].contains(usage) else {
            return
        }

        let key = PressedUsage(device: device, usage: usage)

        // Отпускание кнопки: разрешаем следующее нажатие.
        if value == 0 {
            pressed.remove(key)
            return
        }

        // Игнорируем повторы удерживаемой кнопки и неизвестные значения.
        guard value == 1,
              pressed.insert(key).inserted,
              manager != nil else {
            return
        }

        dispatch(usage)
    }

    private func dispatch(_ usage: UInt32) {
        switch usage {
        case 0x0042:
            SafariController.sendKey(code: SafariController.KeyCode.up)

        case 0x0043:
            SafariController.sendKey(code: SafariController.KeyCode.down)

        case 0x0044:
            SafariController.sendKey(code: SafariController.KeyCode.left)

        case 0x0045:
            SafariController.sendKey(code: SafariController.KeyCode.right)

        case 0x0041:
            SafariController.sendKey(code: SafariController.KeyCode.enter)

        case 0x0224:
            SafariController.sendKey(code: SafariController.KeyCode.escape)

        case 0x0223:
            SafariController.goHome()

        case 0x00E9:
            SafariController.changeVolume(by: 0.05)

        case 0x00EA:
            SafariController.changeVolume(by: -0.05)

        case 0x00E2:
            SafariController.toggleMute()

        case 0x0077:
            SafariController.openYouTube()

        case 0x0078:
            SafariController.openJellyfin()

        default:
            break
        }
    }

    private static func statusCode(_ status: IOReturn) -> String {
        String(format: "0x%08X", UInt32(bitPattern: status))
    }

    // Менеджер работает на главном RunLoop, поэтому callbacks выполняются
    // на главном потоке. Singleton владеет context на время жизни приложения.
    private static let deviceMatched: IOHIDDeviceCallback = {
        context, result, _, device in

        guard let context else {
            return
        }

        let owner = Unmanaged<BluetoothRemoteController>
            .fromOpaque(context)
            .takeUnretainedValue()

        owner.didMatch(ObjectIdentifier(device), result: result)
    }

    private static let deviceRemoved: IOHIDDeviceCallback = {
        context, result, _, device in

        guard let context else {
            return
        }

        let owner = Unmanaged<BluetoothRemoteController>
            .fromOpaque(context)
            .takeUnretainedValue()

        owner.didRemove(ObjectIdentifier(device), result: result)
    }

    private static let valueReceived: IOHIDValueCallback = {
        context, result, _, value in

        guard let context else {
            return
        }

        // Считываем данные, пока IOHIDValue и IOHIDDevice доступны.
        let element = IOHIDValueGetElement(value)
        let page = IOHIDElementGetUsagePage(element)
        let usage = IOHIDElementGetUsage(element)
        let integerValue = IOHIDValueGetIntegerValue(value)
        let deviceID = ObjectIdentifier(IOHIDElementGetDevice(element))

        let owner = Unmanaged<BluetoothRemoteController>
            .fromOpaque(context)
            .takeUnretainedValue()

        owner.didReceive(
            page: page,
            usage: usage,
            value: integerValue,
            device: deviceID,
            result: result
        )
    }
}