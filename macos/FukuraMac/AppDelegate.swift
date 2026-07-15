import AppKit
import ApplicationServices
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let store = SnippetStore()
    private let expander = InputExpander()
    private let statusMenuItem = NSMenuItem(title: "起動中…", action: nil, keyEquivalent: "")
    private let pauseMenuItem = NSMenuItem(title: "展開を一時停止", action: #selector(togglePaused), keyEquivalent: "p")
    private let launchAtLoginMenuItem = NSMenuItem(
        title: "ログイン時に起動",
        action: #selector(toggleLaunchAtLogin),
        keyEquivalent: ""
    )
    private var paused = false
    private lazy var editorWindowController = SnippetEditorWindowController(store: store) { [weak self] snippets in
        self?.expander.update(snippets: snippets)
        self?.setStatus("保存しました（有効 \(snippets.count) 件）")
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureStatusItemIcon()
        configureMenu()
        updateLaunchAtLoginMenuItem()
        reloadSnippets()
        let shouldStartActive = resolveLegacyBonConflict()
        if !shouldStartActive {
            paused = true
            expander.setPaused(true)
            pauseMenuItem.title = "展開を再開"
        }
        if !UserDefaults.standard.bool(forKey: "hasOpenedDictionary") {
            editorWindowController.showEditor()
            UserDefaults.standard.set(true, forKey: "hasOpenedDictionary")
        }
        if !expander.start() {
            showPermissionGuide()
        } else if !shouldStartActive {
            setStatus("旧bonとの二重起動を避けるため展開を停止しました")
        }
    }

    private func configureStatusItemIcon() {
        guard let button = statusItem.button else { return }

        let image = NSImage(named: NSImage.Name("fukuraTemplate-18"))
            ?? NSImage(systemSymbolName: "text.cursor", accessibilityDescription: "fukura")

        image?.size = NSSize(width: 18, height: 18)
        image?.isTemplate = true
        button.image = image
        button.imagePosition = .imageOnly
        button.toolTip = "fukura"
    }

    private func configureMenu() {
        let menu = NSMenu()
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "スニペットを再読み込み", action: #selector(reloadSnippets), keyEquivalent: "r"))
        menu.addItem(NSMenuItem(title: "辞書を編集…", action: #selector(openDictionaryEditor), keyEquivalent: "e"))
        menu.addItem(NSMenuItem(title: "snippets.jsonを開く", action: #selector(openSnippetsFile), keyEquivalent: "o"))
        menu.addItem(NSMenuItem(title: "snippets.jsonをインポート…", action: #selector(importJSON), keyEquivalent: "i"))
        menu.addItem(pauseMenuItem)
        menu.addItem(launchAtLoginMenuItem)
        menu.addItem(NSMenuItem(title: "プライバシー設定を開く", action: #selector(openPrivacySettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "終了", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    @objc private func openDictionaryEditor() {
        editorWindowController.showEditor()
    }

    @objc private func reloadSnippets() {
        do {
            try store.load()
            expander.update(snippets: store.snippets)
            setStatus("読み込みました（有効 \(store.snippets.count) 件）")
        } catch {
            setStatus("辞書を読み込めませんでした")
            showAlert(title: "snippets.json を読み込めません", message: error.localizedDescription)
        }
    }

    @objc private func openSnippetsFile() {
        do {
            try store.ensureDirectory()
            NSWorkspace.shared.open(store.fileURL)
        } catch {
            showAlert(title: "ファイルを開けません", message: error.localizedDescription)
        }
    }

    @objc private func importJSON() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url, let self else {
                return
            }
            do {
                try self.store.importJSON(from: url)
                self.expander.update(snippets: self.store.snippets)
                self.setStatus("インポートしました（有効 \(self.store.snippets.count) 件）")
            } catch {
                self.setStatus("インポートできませんでした")
                self.showAlert(title: "インポートできません", message: error.localizedDescription)
            }
        }
    }

    @objc private func openPrivacySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    @objc private func togglePaused() {
        paused.toggle()
        expander.setPaused(paused)
        pauseMenuItem.title = paused ? "展開を再開" : "展開を一時停止"
        setStatus(paused ? "展開を一時停止しました" : "展開を再開しました")
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            switch SMAppService.mainApp.status {
            case .enabled:
                try SMAppService.mainApp.unregister()
                setStatus("ログイン時起動をオフにしました")
            case .notRegistered, .requiresApproval, .notFound:
                try SMAppService.mainApp.register()
                setStatus("ログイン時起動をオンにしました")
            @unknown default:
                try SMAppService.mainApp.register()
                setStatus("ログイン時起動をオンにしました")
            }
            updateLaunchAtLoginMenuItem()
        } catch {
            updateLaunchAtLoginMenuItem()
            showAlert(
                title: "ログイン時起動を変更できません",
                message: "fukura.app をアプリケーションフォルダへ移動して起動し直してください。\n\n\(error.localizedDescription)"
            )
        }
    }

    private func updateLaunchAtLoginMenuItem() {
        let status = SMAppService.mainApp.status
        launchAtLoginMenuItem.state = status == .enabled ? .on : .off
        launchAtLoginMenuItem.title = status == .requiresApproval
            ? "ログイン時に起動（承認が必要）"
            : "ログイン時に起動"
    }

    private func showPermissionGuide() {
        setStatus("権限が必要です")
        showAlert(
            title: "権限が必要です",
            message: "システム設定 > プライバシーとセキュリティ で Accessibility と Input Monitoring を許可してください。許可後にアプリを再起動してください。"
        )
    }

    private func setStatus(_ message: String) {
        statusMenuItem.title = "状態: \(message)"
        NSLog("[fukura] \(message)")
    }

    private func resolveLegacyBonConflict() -> Bool {
        let legacyBundleID = "com.kaiasai.bon.mac"
        let runningLegacyApps = NSRunningApplication.runningApplications(withBundleIdentifier: legacyBundleID)
            .filter { !$0.isTerminated }
        let legacyAppExists = FileManager.default.fileExists(atPath: "/Applications/bon.app")

        if !runningLegacyApps.isEmpty {
            let alert = NSAlert()
            alert.messageText = "旧bonが起動中です"
            alert.informativeText = "bonとfukuraが同時に入力を展開すると二重置換になります。bonを終了し、システム設定のログイン項目からbonの自動起動をオフにしてください。"
            alert.addButton(withTitle: "bonを終了して設定を開く")
            alert.addButton(withTitle: "fukuraの展開を停止")
            if alert.runModal() == .alertFirstButtonReturn {
                runningLegacyApps.forEach { _ = $0.terminate() }
                let deadline = Date().addingTimeInterval(2)
                while runningLegacyApps.contains(where: { !$0.isTerminated }), Date() < deadline {
                    RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
                }
                openLoginItemsSettings()
                return runningLegacyApps.allSatisfy(\.isTerminated)
            }
            return false
        }

        if legacyAppExists && !UserDefaults.standard.bool(forKey: "hasShownLegacyBonLoginItemGuide") {
            let alert = NSAlert()
            alert.messageText = "旧bonのログイン項目を確認してください"
            alert.informativeText = "bon.appが残っています。二重起動を防ぐため、システム設定 > 一般 > ログイン項目でbonをオフにしてください。"
            alert.addButton(withTitle: "ログイン項目を開く")
            alert.addButton(withTitle: "あとで")
            if alert.runModal() == .alertFirstButtonReturn {
                openLoginItemsSettings()
            }
            UserDefaults.standard.set(true, forKey: "hasShownLegacyBonLoginItemGuide")
        }
        return true
    }

    private func openLoginItemsSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }
}
