import AppKit
import CoreFoundation
import IOKit.hid

/// Passive listener for the Chromecast Bluetooth remote (VID 18D1 / PID 9450).
/// Does not seize the device or synthesize system-wide keyboard events.
public final class BluetoothRemoteController {
    public static let shared = BluetoothRemoteController()

    public enum State: Equatable {
        case stopped
        case waitingForPermission
        case listening(connected: Bool)
        case failed(String)

        public var menuTitle: String {
            switch self {
            case .stopped: return "Пульт Bluetooth: выключен"
            case .waitingForPermission: return "Пульт Bluetooth: требуется разрешение ввода"
            case .listening(true): return "Пульт Bluetooth: подключён"
            case .listening(false): return "Пульт Bluetooth: ожидает пульт"
            case .failed(let message): return "Пульт Bluetooth: ошибка — \(message)"
            }
        }
    }

    public var onStateChange: ((State) -> Void)?
    public private(set) var state: State = .stopped {
        didSet { onStateChange?(state) }
    }

    private let vendorID = 0x18D1
    private let productID = 0x9450
    private var manager: IOHIDManager?
    private var isScheduled = false
    private var isOpen = false
    private var matchedDevices = Set<ObjectIdentifier>()
    private var pressed = Set<PressedUsage>()

    private struct PressedUsage: Hashable {
        let device: ObjectIdentifier
        let usage: UInt32
    }

    private init() {}

    /// Permission request should be triggered only by the user's explicit menu toggle.
    @discardableResult
    public func requestPermission() -> Bool {
        guard #available(macOS 10.15, *) else { return true }
        let requestType = kIOHIDRequestTypeListenEvent
        switch IOHIDCheckAccess(requestType) {
        case kIOHIDAccessTypeGranted:
            return true
        case kIOHIDAccessTypeDenied:
            _ = IOHIDRequestAccess(requestType)
            return false
        case kIOHIDAccessTypeUnknown:
            return IOHIDRequestAccess(requestType)
        @unknown default:
            return false
        }
    }

    /// Idempotent: a second call while running has no effect.
    public func start() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.start() }
            return
        }
        guard manager == nil else { return }
        guard #available(macOS 10.15, *), IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted else {
            state = .waitingForPermission
            return
        }
        guard let newManager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone)) else {
            state = .failed("не удалось создать IOHIDManager")
            return
        }
        manager = newManager
        let matching: [String: Any] = [
            kIOHIDVendorIDKey as String: vendorID,
            kIOHIDProductIDKey as String: productID
        ]
        IOHIDManagerSetDeviceMatching(newManager, matching as CFDictionary)
        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(newManager, Self.deviceMatched, context)
        IOHIDManagerRegisterDeviceRemovalCallback(newManager, Self.deviceRemoved, context)
        IOHIDManagerRegisterInputValueCallback(newManager, Self.valueReceived, context)
        let loop = CFRunLoopGetMain()
        IOHIDManagerScheduleWithRunLoop(newManager, loop, CFRunLoopMode.commonModes.rawValue)
        isScheduled = true
        let result = IOHIDManagerOpen(newManager, IOOptionBits(kIOHIDOptionsTypeNone))
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

    /// Idempotent; unregister callbacks before releasing the manager/context owner.
    public func stop() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.stop() }
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
        if isScheduled {
            IOHIDManagerUnscheduleFromRunLoop(activeManager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
            isScheduled = false
        }
        if isOpen {
            IOHIDManagerClose(activeManager, IOOptionBits(kIOHIDOptionsTypeNone))
            isOpen = false
        }
    }

    private func didMatch(_ identifier: ObjectIdentifier, result: IOReturn) {
        guard manager != nil else { return }
        guard result == kIOReturnSuccess else {
            state = .failed("обнаружение: \(Self.statusCode(result))")
            return
        }
        matchedDevices.insert(identifier)
        state = .listening(connected: true)
    }

    private func didRemove(_ identifier: ObjectIdentifier, result: IOReturn) {
        guard manager != nil else { return }
        matchedDevices.remove(identifier)
        pressed = pressed.filter { $0.device != identifier }
        if result != kIOReturnSuccess {
            state = .failed("отключение: \(Self.statusCode(result))")
        } else {
            state = .listening(connected: !matchedDevices.isEmpty)
        }
    }

    private func didReceive(page: UInt32, usage: UInt32, value: Int, device: ObjectIdentifier, result: IOReturn) {
        guard result == kIOReturnSuccess else {
            state = .failed("чтение ввода: \(Self.statusCode(result))")
            return
        }
        // Accept only explicitly mapped Consumer-page buttons; ignore service,
        // sentinel, vendor-defined, and all unsupported usages.
        guard manager != nil, page == 0x0C,
              [41, 42, 43, 44, 45, 223, 224].contains(usage) else { return }
        let key = PressedUsage(device: device, usage: usage)
        if value == 0 {
            pressed.remove(key)
            return
        }
        guard value == 1, pressed.insert(key).inserted, manager != nil else { return }
        dispatch(usage)
    }

    private func dispatch(_ usage: UInt32) {
        switch usage {
        case 42: SafariController.sendKey(code: SafariController.KeyCode.up)
        case 43: SafariController.sendKey(code: SafariController.KeyCode.down)
        case 44: SafariController.sendKey(code: SafariController.KeyCode.left)
        case 45: SafariController.sendKey(code: SafariController.KeyCode.right)
        case 41: SafariController.sendKey(code: SafariController.KeyCode.enter)
        case 224: SafariController.sendKey(code: SafariController.KeyCode.escape)
        case 223: SafariController.goHome()
        default: break
        }
    }

    private static func statusCode(_ status: IOReturn) -> String {
        String(format: "0x%08X", UInt32(bitPattern: status))
    }

    // The manager is scheduled on the main run loop, so callbacks execute on
    // the main thread and are handled synchronously. This avoids queued work
    // outliving a stop/restart cycle. The singleton owns the unretained context
    // for the process lifetime; cleanup unregisters callbacks before closing.
    private static let deviceMatched: IOHIDDeviceCallback = { context, result, _, device in
        guard let context else { return }
        let owner = Unmanaged<BluetoothRemoteController>.fromOpaque(context).takeUnretainedValue()
        owner.didMatch(ObjectIdentifier(device), result: result)
    }
    private static let deviceRemoved: IOHIDDeviceCallback = { context, result, _, device in
        guard let context else { return }
        let owner = Unmanaged<BluetoothRemoteController>.fromOpaque(context).takeUnretainedValue()
        owner.didRemove(ObjectIdentifier(device), result: result)
    }
    private static let valueReceived: IOHIDValueCallback = { context, result, _, value in
        guard let context else { return }
        // Extract scalar values while IOHIDValue/IOHIDDevice are valid.
        let element = IOHIDValueGetElement(value)
        let page = IOHIDElementGetUsagePage(element)
        let usage = IOHIDElementGetUsage(element)
        let integerValue = IOHIDValueGetIntegerValue(value)
        let deviceID = ObjectIdentifier(IOHIDValueGetDevice(value))
        let owner = Unmanaged<BluetoothRemoteController>.fromOpaque(context).takeUnretainedValue()
        owner.didReceive(page: page, usage: usage, value: integerValue, device: deviceID, result: result)
    }
}
