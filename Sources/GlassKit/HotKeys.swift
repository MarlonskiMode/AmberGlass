import Carbon.HIToolbox

/// A system-wide shortcut that works while other apps are focused.
public struct HotKey {
    public static let controlOptionCommand = controlKey | optionKey | cmdKey
    public static let controlOptionShiftCommand = controlKey | optionKey | shiftKey | cmdKey

    let keyCode: Int
    let modifiers: Int
    let action: @MainActor () -> Void

    public init(keyCode: Int, modifiers: Int, action: @escaping @MainActor () -> Void) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.action = action
    }
}

@MainActor
public enum HotKeys {
    private static var actions: [UInt32: @MainActor () -> Void] = [:]
    private static var refs: [EventHotKeyRef] = []
    private static var handlerInstalled = false

    public static func register(_ hotKeys: [HotKey]) {
        installHandler()
        for hotKey in hotKeys {
            let id = UInt32(actions.count + 1)
            var ref: EventHotKeyRef?
            let hotKeyID = EventHotKeyID(signature: OSType(0x4254_4E54), id: id)
            RegisterEventHotKey(UInt32(hotKey.keyCode), UInt32(hotKey.modifiers), hotKeyID, GetApplicationEventTarget(), 0, &ref)
            if let ref {
                refs.append(ref)
                actions[id] = hotKey.action
            }
        }
    }

    static func handle(_ id: UInt32) {
        actions[id]?()
    }

    private static func installHandler() {
        guard !handlerInstalled else { return }
        handlerInstalled = true
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
            var hotKeyID = EventHotKeyID()
            GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            let id = hotKeyID.id
            Task { @MainActor in HotKeys.handle(id) }
            return noErr
        }, 1, &spec, nil, nil)
    }
}
