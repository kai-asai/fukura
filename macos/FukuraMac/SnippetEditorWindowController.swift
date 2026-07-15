import AppKit

final class SnippetEditorWindowController: NSWindowController, NSWindowDelegate, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate, NSTextFieldDelegate, NSTextViewDelegate {
    private let store: SnippetStore
    private let onSave: ([Snippet]) -> Void
    private var snippets: [Snippet] = []
    private var filteredIndices: [Int] = []
    private var selectedIndex: Int?
    private var dirty = false
    private var isLoadingFields = false

    private let searchField = NSSearchField()
    private let tableView = NSTableView()
    private let triggerField = NSTextField()
    private let bodyTextView = NSTextView()
    private let enabledCheckbox = NSButton(checkboxWithTitle: "このスニペットを有効にする", target: nil, action: nil)
    private let countLabel = NSTextField(labelWithString: "")
    private let statusLabel = NSTextField(labelWithString: "")
    private let saveButton = NSButton(title: "保存", target: nil, action: nil)

    init(store: SnippetStore, onSave: @escaping ([Snippet]) -> Void) {
        self.store = store
        self.onSave = onSave
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 590),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "スニペット辞書"
        window.minSize = NSSize(width: 720, height: 480)
        window.center()
        super.init(window: window)
        window.delegate = self
        buildUI()
    }

    required init?(coder: NSCoder) { nil }

    func showEditor() {
        if window?.isVisible != true {
            reloadFromStore()
        }
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    private func buildUI() {
        guard let content = window?.contentView else { return }

        let split = NSSplitView()
        split.isVertical = true
        split.dividerStyle = .thin
        split.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(split)

        let sidebar = NSView()
        let detail = NSView()
        split.addArrangedSubview(sidebar)
        split.addArrangedSubview(detail)
        sidebar.widthAnchor.constraint(equalToConstant: 280).isActive = true

        searchField.placeholderString = "トリガー・本文を検索"
        searchField.delegate = self
        searchField.translatesAutoresizingMaskIntoConstraints = false
        sidebar.addSubview(searchField)

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("snippet"))
        column.title = "スニペット"
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.rowHeight = 42
        tableView.delegate = self
        tableView.dataSource = self
        let scroll = NSScrollView()
        scroll.documentView = tableView
        scroll.hasVerticalScroller = true
        scroll.translatesAutoresizingMaskIntoConstraints = false
        sidebar.addSubview(scroll)

        let addButton = NSButton(title: "＋", target: self, action: #selector(addSnippet))
        addButton.toolTip = "新しいスニペット"
        let duplicateButton = NSButton(title: "複製", target: self, action: #selector(duplicateSnippet))
        let deleteButton = NSButton(title: "削除", target: self, action: #selector(deleteSnippet))
        let sideButtons = NSStackView(views: [addButton, duplicateButton, deleteButton])
        sideButtons.spacing = 8
        sideButtons.translatesAutoresizingMaskIntoConstraints = false
        sidebar.addSubview(sideButtons)

        let title = NSTextField(labelWithString: "辞書を編集")
        title.font = .systemFont(ofSize: 22, weight: .semibold)
        let hint = NSTextField(wrappingLabelWithString: "展開する文章はそのまま入力できます。改行は Return キーで入力し、\\n のような記号を書く必要はありません。")
        hint.textColor = .secondaryLabelColor
        let triggerLabel = NSTextField(labelWithString: "トリガー")
        triggerLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        triggerField.placeholderString = ";mail"
        triggerField.delegate = self
        let bodyLabel = NSTextField(labelWithString: "展開する文章")
        bodyLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        bodyTextView.font = .systemFont(ofSize: 14)
        bodyTextView.isRichText = false
        bodyTextView.isAutomaticQuoteSubstitutionEnabled = false
        bodyTextView.isAutomaticDashSubstitutionEnabled = false
        bodyTextView.textContainerInset = NSSize(width: 8, height: 8)
        bodyTextView.delegate = self
        let bodyScroll = NSScrollView()
        bodyScroll.documentView = bodyTextView
        bodyScroll.hasVerticalScroller = true
        bodyScroll.borderType = .bezelBorder
        bodyScroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 220).isActive = true
        enabledCheckbox.target = self
        enabledCheckbox.action = #selector(fieldChanged)
        countLabel.textColor = .secondaryLabelColor
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byTruncatingTail
        saveButton.target = self
        saveButton.action = #selector(saveChanges)
        saveButton.keyEquivalent = "s"
        saveButton.keyEquivalentModifierMask = .command
        let revertButton = NSButton(title: "変更を戻す", target: self, action: #selector(revertChanges))
        let actionButtons = NSStackView(views: [statusLabel, NSView(), revertButton, saveButton])
        actionButtons.orientation = .horizontal
        actionButtons.spacing = 10

        let fields = NSStackView(views: [title, hint, triggerLabel, triggerField, bodyLabel, bodyScroll, countLabel, enabledCheckbox, actionButtons])
        fields.orientation = .vertical
        fields.alignment = .leading
        fields.spacing = 10
        fields.translatesAutoresizingMaskIntoConstraints = false
        for view in [hint, triggerField, bodyScroll, countLabel, enabledCheckbox, actionButtons] {
            view.widthAnchor.constraint(equalTo: fields.widthAnchor).isActive = true
        }
        detail.addSubview(fields)

        NSLayoutConstraint.activate([
            split.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            split.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            split.topAnchor.constraint(equalTo: content.topAnchor),
            split.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            searchField.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: 12),
            searchField.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: -12),
            searchField.topAnchor.constraint(equalTo: sidebar.topAnchor, constant: 12),
            scroll.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 8),
            scroll.bottomAnchor.constraint(equalTo: sideButtons.topAnchor, constant: -8),
            sideButtons.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: 12),
            sideButtons.bottomAnchor.constraint(equalTo: sidebar.bottomAnchor, constant: -12),
            fields.leadingAnchor.constraint(equalTo: detail.leadingAnchor, constant: 28),
            fields.trailingAnchor.constraint(equalTo: detail.trailingAnchor, constant: -28),
            fields.topAnchor.constraint(equalTo: detail.topAnchor, constant: 24),
            fields.bottomAnchor.constraint(lessThanOrEqualTo: detail.bottomAnchor, constant: -20)
        ])
    }

    private func reloadFromStore() {
        snippets = store.document.snippets
        dirty = false
        statusLabel.stringValue = ""
        applyFilter(selecting: snippets.isEmpty ? nil : 0)
    }

    private func applyFilter(selecting index: Int? = nil) {
        let query = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        filteredIndices = snippets.indices.filter { index in
            query.isEmpty || snippets[index].trigger.lowercased().contains(query) || snippets[index].body.lowercased().contains(query)
        }
        tableView.reloadData()
        if let index, let row = filteredIndices.firstIndex(of: index) {
            tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            select(index: index)
        } else if let first = filteredIndices.first {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
            select(index: first)
        } else {
            select(index: nil)
        }
    }

    private func select(index: Int?) {
        commitFields()
        selectedIndex = index
        isLoadingFields = true
        if let index {
            let snippet = snippets[index]
            triggerField.stringValue = snippet.trigger
            bodyTextView.string = snippet.body
            enabledCheckbox.state = (snippet.enabled ?? true) ? .on : .off
        } else {
            triggerField.stringValue = ""
            bodyTextView.string = ""
            enabledCheckbox.state = .off
        }
        isLoadingFields = false
        setFieldsEnabled(index != nil)
        updateCounts()
    }

    private func setFieldsEnabled(_ enabled: Bool) {
        triggerField.isEnabled = enabled
        bodyTextView.isEditable = enabled
        enabledCheckbox.isEnabled = enabled
    }

    private func commitFields() {
        guard !isLoadingFields, let index = selectedIndex, snippets.indices.contains(index) else { return }
        let old = snippets[index]
        snippets[index] = Snippet(
            id: old.id,
            trigger: triggerField.stringValue,
            body: bodyTextView.string,
            enabled: enabledCheckbox.state == .on,
            tags: old.tags,
            updatedAt: old.updatedAt
        )
    }

    private func updateCounts() {
        countLabel.stringValue = "本文: \(bodyTextView.string.count) / \(SnippetStore.maxBodyLength) 文字・\(bodyTextView.string.components(separatedBy: "\n").count) 行"
        saveButton.isEnabled = dirty
        window?.isDocumentEdited = dirty
    }

    func numberOfRows(in tableView: NSTableView) -> Int { filteredIndices.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let snippet = snippets[filteredIndices[row]]
        let cell = NSTableCellView()
        let label = NSTextField(labelWithString: snippet.trigger.isEmpty ? "（トリガー未入力）" : snippet.trigger)
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = (snippet.enabled ?? true) ? .labelColor : .tertiaryLabelColor
        let preview = snippet.body.replacingOccurrences(of: "\n", with: " ↵ ")
        let subtitle = NSTextField(labelWithString: preview)
        subtitle.font = .systemFont(ofSize: 11)
        subtitle.textColor = .secondaryLabelColor
        let stack = NSStackView(views: [label, subtitle])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 1
        stack.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
            stack.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
        ])
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = tableView.selectedRow
        select(index: row >= 0 && row < filteredIndices.count ? filteredIndices[row] : nil)
    }

    func controlTextDidChange(_ obj: Notification) {
        if obj.object as? NSSearchField === searchField {
            commitFields()
            applyFilter(selecting: selectedIndex)
        } else {
            fieldChanged()
        }
    }

    func textDidChange(_ notification: Notification) { fieldChanged() }

    @objc private func fieldChanged() {
        guard !isLoadingFields else { return }
        dirty = true
        commitFields()
        tableView.reloadData()
        updateCounts()
        statusLabel.stringValue = "未保存の変更があります"
    }

    @objc private func addSnippet() {
        guard snippets.count < SnippetStore.maxSnippetCount else { return }
        commitFields()
        var suffix = snippets.count + 1
        var trigger = ";new\(suffix)"
        while snippets.contains(where: { $0.trigger == trigger }) {
            suffix += 1
            trigger = ";new\(suffix)"
        }
        snippets.append(Snippet(id: UUID().uuidString.lowercased(), trigger: trigger, body: "ここに展開する文章を入力", enabled: true, tags: nil, updatedAt: nil))
        dirty = true
        searchField.stringValue = ""
        applyFilter(selecting: snippets.count - 1)
        triggerField.selectText(nil)
        updateCounts()
    }

    @objc private func duplicateSnippet() {
        commitFields()
        guard let index = selectedIndex else { return }
        let source = snippets[index]
        var suffix = 2
        var trigger = "\(source.trigger)-\(suffix)"
        while snippets.contains(where: { $0.trigger == trigger }) {
            suffix += 1
            trigger = "\(source.trigger)-\(suffix)"
        }
        snippets.insert(Snippet(id: UUID().uuidString.lowercased(), trigger: trigger, body: source.body, enabled: source.enabled, tags: source.tags, updatedAt: nil), at: index + 1)
        dirty = true
        searchField.stringValue = ""
        applyFilter(selecting: index + 1)
        updateCounts()
    }

    @objc private func deleteSnippet() {
        guard let index = selectedIndex else { return }
        let alert = NSAlert()
        alert.messageText = "「\(snippets[index].trigger)」を削除しますか？"
        alert.informativeText = "保存するまでファイルには反映されません。"
        alert.addButton(withTitle: "削除")
        alert.addButton(withTitle: "キャンセル")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        snippets.remove(at: index)
        dirty = true
        applyFilter(selecting: snippets.indices.contains(index) ? index : snippets.indices.last)
        updateCounts()
    }

    @objc private func saveChanges() {
        commitFields()
        do {
            try store.save(snippets: snippets)
            snippets = store.document.snippets
            dirty = false
            statusLabel.stringValue = "保存しました（バックアップも更新済み）"
            onSave(store.snippets)
            applyFilter(selecting: selectedIndex)
            updateCounts()
        } catch {
            let alert = NSAlert()
            alert.messageText = "保存できません"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }

    @objc private func revertChanges() {
        guard !dirty || confirmDiscard() else { return }
        reloadFromStore()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool { !dirty || confirmDiscard() }

    private func confirmDiscard() -> Bool {
        let alert = NSAlert()
        alert.messageText = "未保存の変更があります"
        alert.informativeText = "変更を破棄してもよいですか？"
        alert.addButton(withTitle: "変更を破棄")
        alert.addButton(withTitle: "編集を続ける")
        return alert.runModal() == .alertFirstButtonReturn
    }
}
