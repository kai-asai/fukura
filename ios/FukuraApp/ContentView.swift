import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var store: SnippetSharedStore
    @State private var importing = false
    @State private var exporting = false
    @State private var exportDocument = SnippetJsonDocument()
    @State private var editing: Snippet?
    @State private var errorMessage: String?
    @State private var query = ""

    private var visibleSnippets: [Snippet] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return store.snippets }
        return store.snippets.filter { snippet in
            snippet.trigger.localizedCaseInsensitiveContains(trimmed)
                || snippet.body.localizedCaseInsensitiveContains(trimmed)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(store.message)
                    Text("iOSの制約により、Fukura Keyboard を選んでいる入力欄だけで展開できます。ほかのキーボードの入力は監視せず、システム全体の置換はしません。フルアクセスは要求しません。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("このアプリについて") {
                    Link(destination: URL(string: "https://github.com/kai-asai/fukura/blob/main/PRIVACY.md")!) {
                        Label("プライバシーポリシー", systemImage: "hand.raised")
                    }
                }
                Section("スニペット") {
                    ForEach(visibleSnippets) { snippet in
                        Button { editing = snippet } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(snippet.trigger).font(.headline)
                                    if snippet.enabled == false {
                                        Text("停止中").font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                Text(snippet.body.replacingOccurrences(of: "\n", with: " ↵ "))
                                    .lineLimit(2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { offsets in
                        let removed = Set(offsets.map { visibleSnippets[$0].id })
                        save(store.snippets.filter { !removed.contains($0.id) })
                    }
                }
            }
            .navigationTitle("fukura")
            .searchable(text: $query, prompt: "トリガー・本文を検索")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { importing = true } label: { Image(systemName: "square.and.arrow.down") }
                        .accessibilityLabel("snippets.json をインポート")
                    Button { beginExport() } label: { Image(systemName: "square.and.arrow.up") }
                        .accessibilityLabel("snippets.json を書き出す")
                    Button {
                        editing = Snippet(id: UUID().uuidString.lowercased(), trigger: nextTrigger(), body: "", enabled: true, tags: nil)
                    } label: { Image(systemName: "plus") }
                        .accessibilityLabel("スニペットを追加")
                }
            }
            .sheet(item: $editing) { snippet in
                SnippetEditorView(snippet: snippet) { updated in
                    var items = store.snippets
                    if let index = items.firstIndex(where: { $0.id == updated.id }) {
                        items[index] = updated
                    } else {
                        items.append(updated)
                    }
                    save(items)
                    editing = nil
                }
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
                switch result {
                case .success(let url):
                    do {
                        try store.importJSON(from: url)
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
            .fileExporter(
                isPresented: $exporting,
                document: exportDocument,
                contentType: .json,
                defaultFilename: "snippets.json"
            ) { result in
                if case .failure(let error) = result {
                    errorMessage = error.localizedDescription
                }
            }
            .alert("操作できません", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func nextTrigger() -> String {
        let triggers = Set(store.snippets.map(\.trigger))
        var candidate = ";new"
        var number = 2
        while triggers.contains(candidate) {
            candidate = ";new\(number)"
            number += 1
        }
        return candidate
    }

    private func beginExport() {
        do {
            exportDocument = SnippetJsonDocument(data: try store.exportData())
            exporting = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func save(_ snippets: [Snippet]) {
        do {
            try store.save(snippets)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct SnippetEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let snippet: Snippet
    let onSave: (Snippet) -> Void
    @State private var trigger: String
    @State private var expansionBody: String
    @State private var enabled: Bool

    init(snippet: Snippet, onSave: @escaping (Snippet) -> Void) {
        self.snippet = snippet
        self.onSave = onSave
        _trigger = State(initialValue: snippet.trigger)
        _expansionBody = State(initialValue: snippet.body)
        _enabled = State(initialValue: snippet.enabled ?? true)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("トリガー") {
                    TextField(";mail", text: $trigger)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                Section {
                    TextEditor(text: $expansionBody).frame(minHeight: 220)
                    Text("改行はReturnで入力できます。\\nを書く必要はありません。\n本文: \(expansionBody.count) / 8000文字・\(expansionBody.isEmpty ? 0 : expansionBody.components(separatedBy: "\n").count)行")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("展開する文章")
                }
                Section {
                    Toggle("このスニペットを有効にする", isOn: $enabled)
                }
            }
            .navigationTitle("辞書を編集")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(Snippet(id: snippet.id, trigger: trigger, body: expansionBody, enabled: enabled, tags: snippet.tags, updatedAt: snippet.updatedAt))
                    }
                    .disabled(trigger.isEmpty || expansionBody.isEmpty)
                }
            }
        }
    }
}

struct SnippetJsonDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data = Data()) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
