import ApplicationServices
import Carbon
import Foundation

struct KeyboardInputState {
    var modifiers: Set<KeyModifier> = []
    var pressedKeys: Set<String> = []

    var symbols: Set<String> {
        let modifierSymbols = modifiers.map { KeyCombo.normalizedSymbol($0.symbol) }
        return Set(modifierSymbols).union(pressedKeys.map(KeyCombo.normalizedSymbol))
    }
}

final class KeyboardEventMonitor {
    enum StartError: LocalizedError {
        case eventTapUnavailable

        var errorDescription: String? {
            switch self {
            case .eventTapUnavailable:
                return "无法启动全局键盘监听。请为 Y-Keys 开启「辅助功能」权限后重启 App。"
            }
        }
    }

    var onDoubleTapLeftCommand: (() -> Void)?
    var onInputStateChanged: ((KeyboardInputState) -> Void)?
    var onKeyDown: ((KeyboardInputState, String) -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var state = KeyboardInputState()
    private var leftCommandDown = false
    private var leftCommandTapCandidate = false
    private var lastLeftCommandTapAt: TimeInterval = 0

    private let doubleTapInterval: TimeInterval = 0.38

    deinit {
        stop()
    }

    func start() throws {
        guard eventTap == nil else { return }

        let mask = (1 << CGEventType.flagsChanged.rawValue)
            | (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(mask),
            callback: KeyboardEventMonitor.eventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            throw StartError.eventTapUnavailable
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        runLoopSource = nil
        eventTap = nil
    }

    private func handle(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) {
        switch type {
        case .flagsChanged:
            handleFlagsChanged(event)
        case .keyDown:
            handleKeyDown(event)
        case .keyUp:
            handleKeyUp(event)
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
        default:
            break
        }
    }

    private func handleFlagsChanged(_ event: CGEvent) {
        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
        let modifiers = modifiers(from: event.flags)

        if keyCode == kVK_Command {
            let isDown = modifiers.contains(.command)
            if isDown && !leftCommandDown {
                leftCommandTapCandidate = state.pressedKeys.isEmpty
            } else if !isDown && leftCommandDown {
                registerLeftCommandTapIfNeeded()
            }
            leftCommandDown = isDown
        } else if leftCommandDown, modifierKeyCodes.contains(keyCode) {
            leftCommandTapCandidate = false
        }

        state.modifiers = modifiers
        emitStateChanged()
    }

    private func handleKeyDown(_ event: CGEvent) {
        if event.getIntegerValueField(.keyboardEventAutorepeat) != 0 {
            return
        }

        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
        guard !modifierKeyCodes.contains(keyCode), let key = KeyCodeDisplay.normalizedDisplayName(for: keyCode) else {
            return
        }

        state.pressedKeys.insert(key)
        if leftCommandDown {
            leftCommandTapCandidate = false
        }
        emitStateChanged()
        onKeyDown?(state, key)
    }

    private func handleKeyUp(_ event: CGEvent) {
        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
        guard !modifierKeyCodes.contains(keyCode), let key = KeyCodeDisplay.normalizedDisplayName(for: keyCode) else {
            return
        }

        state.pressedKeys.remove(key)
        emitStateChanged()
    }

    private func registerLeftCommandTapIfNeeded() {
        guard leftCommandTapCandidate, state.pressedKeys.isEmpty else {
            leftCommandTapCandidate = false
            return
        }

        let now = Date().timeIntervalSinceReferenceDate
        if now - lastLeftCommandTapAt <= doubleTapInterval {
            lastLeftCommandTapAt = 0
            leftCommandTapCandidate = false
            DispatchQueue.main.async { [weak self] in
                self?.onDoubleTapLeftCommand?()
            }
        } else {
            lastLeftCommandTapAt = now
            leftCommandTapCandidate = false
        }
    }

    private func emitStateChanged() {
        let current = state
        DispatchQueue.main.async { [weak self] in
            self?.onInputStateChanged?(current)
        }
    }

    private func modifiers(from flags: CGEventFlags) -> Set<KeyModifier> {
        var result: Set<KeyModifier> = []
        if flags.contains(.maskControl) { result.insert(.control) }
        if flags.contains(.maskAlternate) { result.insert(.option) }
        if flags.contains(.maskShift) { result.insert(.shift) }
        if flags.contains(.maskCommand) { result.insert(.command) }
        if flags.contains(.maskSecondaryFn) { result.insert(.function) }
        return result
    }

    private let modifierKeyCodes = Set<Int>([
        Int(kVK_Command),
        Int(kVK_RightCommand),
        Int(kVK_Shift),
        Int(kVK_RightShift),
        Int(kVK_Option),
        Int(kVK_RightOption),
        Int(kVK_Control),
        Int(kVK_RightControl),
        Int(kVK_Function),
        Int(kVK_CapsLock)
    ])

    private static let eventTapCallback: CGEventTapCallBack = { proxy, type, event, userInfo in
        guard let userInfo else { return Unmanaged.passUnretained(event) }
        let monitor = Unmanaged<KeyboardEventMonitor>.fromOpaque(userInfo).takeUnretainedValue()
        monitor.handle(proxy: proxy, type: type, event: event)
        return Unmanaged.passUnretained(event)
    }
}
