import AppKit
import ApplicationServices
import Carbon
import OSLog

final class InputExpander {
    private struct PasteboardEntry {
        let type: NSPasteboard.PasteboardType
        let data: Data
    }

    private let matcher = SnippetMatcher()
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var healthTimer: Timer?
    private let logger = Logger(subsystem: "com.kaiasai.fukura.mac", category: "InputMonitoring")
    private var generation = 0
    private var secureInput = false
    private var lastStatus = ""
    private var receivedEvents = 0
    private var readableEvents = 0
    private var matches = 0
    private var timeoutCount = 0
    private var recoveryCount = 0
    private let syntheticEventTag: Int64 = 0x66756B757261
    var onStatusChange: ((String) -> Void)?
    private let pasteboard = NSPasteboard.general
    private var paused = false

    func update(snippets: [Snippet]) {
        resetPendingInput()
        matcher.update(snippets: snippets)
    }

    func start() -> Bool {
        stop()
        receivedEvents = 0
        readableEvents = 0
        matches = 0
        timeoutCount = 0
        recoveryCount = 0
        secureInput = IsSecureEventInputEnabled()
        let timer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
            self?.refreshStatus()
        }
        healthTimer = timer
        RunLoop.main.add(timer, forMode: .common)
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        guard AXIsProcessTrustedWithOptions(options) else {
            refreshStatus()
            return false
        }

        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                let expander = Unmanaged<InputExpander>.fromOpaque(refcon!).takeUnretainedValue()
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    expander.handleDisabledTap(type: type)
                    return Unmanaged.passUnretained(event)
                }
                guard type == .keyDown,
                      event.getIntegerValueField(.eventSourceUserData) != expander.syntheticEventTag else {
                    return Unmanaged.passUnretained(event)
                }
                expander.handle(event: event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        guard let eventTap else {
            refreshStatus()
            return false
        }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0) else {
            stop()
            refreshStatus()
            return false
        }
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        refreshStatus()
        return CGEvent.tapIsEnabled(tap: eventTap)
    }

    func stop() {
        healthTimer?.invalidate()
        healthTimer = nil
        resetPendingInput()
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        runLoopSource = nil
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
        }
        eventTap = nil
    }

    func setPaused(_ paused: Bool) {
        self.paused = paused
        resetPendingInput()
        refreshStatus()
    }

    private func resetPendingInput() {
        generation += 1
        matcher.reset()
    }

    private func handleDisabledTap(type: CGEventType) {
        resetPendingInput()
        if type == .tapDisabledByTimeout {
            timeoutCount += 1
            // Re-enable only a timeout, never a user/security-triggered disable.
            if let eventTap, AXIsProcessTrusted(), CGPreflightPostEventAccess() {
                CGEvent.tapEnable(tap: eventTap, enable: true)
                if CGEvent.tapIsEnabled(tap: eventTap) { recoveryCount += 1 }
            }
            logger.notice("入力監視がタイムアウトしました。復帰回数: \(self.recoveryCount, privacy: .public)")
        } else {
            logger.notice("入力監視の無効化通知を受信しました。手動で監視を再開始してください")
        }
        refreshStatus()
    }

    private func refreshStatus() {
        let currentSecureInput = IsSecureEventInputEnabled()
        if secureInput != currentSecureInput {
            secureInput = currentSecureInput
            resetPendingInput()
        }
        let status: String
        if paused {
            status = "一時停止中"
        } else if !AXIsProcessTrusted() {
            status = "デバイスの制御権限が必要"
        } else if !CGPreflightPostEventAccess() {
            status = "入力イベント送信の権限が必要"
        } else if secureInput {
            status = "セキュア入力により待機中"
        } else if let eventTap, CGEvent.tapIsEnabled(tap: eventTap) {
            status = "有効（入力受信は診断情報で確認）"
        } else {
            status = "停止中（入力監視を再開始してください）"
        }
        if status != lastStatus {
            lastStatus = status
            // Only fixed status text is public; no typed text or snippets.
            logger.notice("入力監視: \(status, privacy: .public)")
            onStatusChange?(status)
        }
    }

    func diagnosticReport() -> String {
        refreshStatus()
        let enabled = eventTap.map { CGEvent.tapIsEnabled(tap: $0) } ?? false
        let report = """
        OS: \(ProcessInfo.processInfo.operatingSystemVersionString)
        監視: \(lastStatus)
        Accessibility: \(AXIsProcessTrusted())
        ListenEvent: \(CGPreflightListenEventAccess())
        PostEvent: \(CGPreflightPostEventAccess())
        SecureInput: \(secureInput)
        EventTap作成済み: \(eventTap != nil) / 有効: \(enabled)
        キー受信: \(receivedEvents) / 判定可能な文字: \(readableEvents)
        トリガー一致: \(matches)
        タイムアウト: \(timeoutCount) / 復帰: \(recoveryCount)
        """
        logger.notice("\(report, privacy: .public)")
        return report
    }

    private func handle(event: CGEvent) {
        receivedEvents += 1
        guard !paused, !IsSecureEventInputEnabled() else {
            resetPendingInput()
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
        readableEvents += 1
        guard let snippet = matcher.push(characters) else {
            return
        }
        matches += 1
        let scheduledGeneration = generation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) { [weak self] in
            guard let self, self.generation == scheduledGeneration, !self.paused,
                  !IsSecureEventInputEnabled(), AXIsProcessTrusted(),
                  CGPreflightPostEventAccess(),
                  let tap = self.eventTap, CGEvent.tapIsEnabled(tap: tap) else { return }
            self.replaceTrigger(triggerLength: snippet.trigger.count, body: snippet.body)
        }
    }

    private func replaceTrigger(triggerLength: Int, body: String) {
        logger.notice("スニペットの展開処理を開始します")
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
        for keyDown in [true, false] {
            let event = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: keyDown)
            event?.setIntegerValueField(.eventSourceUserData, value: syntheticEventTag)
            event?.post(tap: .cghidEventTap)
        }
    }

    private func postPaste() {
        let source = CGEventSource(stateID: .hidSystemState)
        let commandDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true)
        let commandUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
        commandDown?.flags = .maskCommand
        commandUp?.flags = .maskCommand
        commandDown?.setIntegerValueField(.eventSourceUserData, value: syntheticEventTag)
        commandUp?.setIntegerValueField(.eventSourceUserData, value: syntheticEventTag)
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
