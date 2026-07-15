import AppKit
import ApplicationServices

final class InputExpander {
    private struct PasteboardEntry {
        let type: NSPasteboard.PasteboardType
        let data: Data
    }

    private let matcher = SnippetMatcher()
    private var eventTap: CFMachPort?
    private let pasteboard = NSPasteboard.general
    private var paused = false

    func update(snippets: [Snippet]) {
        matcher.update(snippets: snippets)
    }

    func start() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        guard AXIsProcessTrustedWithOptions(options) else {
            NSLog("[fukura] アクセシビリティ権限が許可されていません")
            return false
        }

        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, _, event, refcon in
                let expander = Unmanaged<InputExpander>.fromOpaque(refcon!).takeUnretainedValue()
                expander.handle(event: event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        guard let eventTap else {
            NSLog("[fukura] 入力イベントを監視できません。入力監視権限を確認してください")
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        return true
    }

    func stop() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        eventTap = nil
    }

    func setPaused(_ paused: Bool) {
        self.paused = paused
        matcher.reset()
    }

    private func handle(event: CGEvent) {
        guard !paused else {
            return
        }
        guard event.flags.intersection([.maskCommand, .maskControl, .maskAlternate]).isEmpty else {
            matcher.reset()
            return
        }
        guard let characters = event.keyboardString(), characters.count == 1 else {
            matcher.reset()
            return
        }
        guard let scalar = characters.unicodeScalars.first,
              !CharacterSet.controlCharacters.contains(scalar) else {
            matcher.reset()
            return
        }
        guard let snippet = matcher.push(characters) else {
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) { [weak self] in
            self?.replaceTrigger(triggerLength: snippet.trigger.count, body: snippet.body)
        }
    }

    private func replaceTrigger(triggerLength: Int, body: String) {
        NSLog("[fukura] スニペットを展開します（削除 \(triggerLength) 文字）")
        for _ in 0..<triggerLength {
            postKey(keyCode: 51)
        }

        let previousItems = snapshotPasteboard()
        pasteboard.clearContents()
        pasteboard.setString(body, forType: .string)
        let expansionChangeCount = pasteboard.changeCount
        postPaste()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self, self.pasteboard.changeCount == expansionChangeCount else {
                return
            }
            self.restorePasteboard(previousItems)
        }
    }

    private func snapshotPasteboard() -> [[PasteboardEntry]] {
        pasteboard.pasteboardItems?.map { item in
            item.types.compactMap { type in
                item.data(forType: type).map { PasteboardEntry(type: type, data: $0) }
            }
        } ?? []
    }

    private func restorePasteboard(_ snapshot: [[PasteboardEntry]]) {
        pasteboard.clearContents()
        guard !snapshot.isEmpty else {
            return
        }

        let items = snapshot.map { entries in
            let item = NSPasteboardItem()
            for entry in entries {
                item.setData(entry.data, forType: entry.type)
            }
            return item
        }
        pasteboard.writeObjects(items)
    }

    private func postKey(keyCode: CGKeyCode) {
        CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)?.post(tap: .cghidEventTap)
        CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)?.post(tap: .cghidEventTap)
    }

    private func postPaste() {
        let source = CGEventSource(stateID: .hidSystemState)
        let commandDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true)
        let commandUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
        commandDown?.flags = .maskCommand
        commandUp?.flags = .maskCommand
        commandDown?.post(tap: .cghidEventTap)
        commandUp?.post(tap: .cghidEventTap)
    }
}

private extension CGEvent {
    func keyboardString() -> String? {
        var length = 0
        var chars = [UniChar](repeating: 0, count: 8)
        keyboardGetUnicodeString(maxStringLength: 8, actualStringLength: &length, unicodeString: &chars)
        guard length > 0 else {
            return nil
        }
        return String(utf16CodeUnits: chars, count: length)
    }
}
