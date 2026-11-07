import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var store: SnippetSharedStore
    @State private var importing = false
    @State private var editing: Snippet?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(store.message)
                    Text("標準キーボードでは展開できません。設定 > 一般 > キーボード > キーボード > 新しいキーボードを追加 から Fukura Keyboard を追加してください。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("このアプリについて") {
                    Link(destination: URL(string: "https://github.com/kai-asai/fukura/blob/main/PRIVACY.md")!) {
                        Label("プライバシーポリシー", systemImage: "hand.raised")
                    }
                }
                Section("スニペット") {
                    ForEach(store.snippets) { snippet in
                        Button { editing = snippet } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack { Text(snippet.trigger).font(.headline); if snippet.enabled == false { Text("停止中").font(.caption).foregroundStyle(.secondary) } }
                                Text(snippet.body.replacingOccurrences(of: "\n", with: " ↵ ")).lineLimit(2).foregroundStyle(.secondary)
                            }
                        }.buttonStyle(.plain)
                    }
                    .onDelete { offsets in save(store.snippets.enumerated().filter { !offsets.contains($0.offset) }.map(\.element)) }
                }
            }
            .navigationTitle("fukura")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { importing = true } label: { Image(systemName: "square.and.arrow.down") }
                    Button { editing = Snippet(id: UUID().uuidString.lowercased(), trigger: ";new", body: "", enabled: true, tags: nil) } label: { Image(systemName: "plus") }
                }
            }
            .sheet(item: $editing) { snippet in
                SnippetEditorView(snippet: snippet) { updated in
                    var items = store.snippets
                    if let index = items.firstIndex(where: { $0.id == updated.id }) { items[index] = updated } else { items.append(updated) }
                    save(items)
                    editing = nil
                }
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
                switch result {
                case .success(let url):
                    store.importJSON(from: url)
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
            .alert("操作できません", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) { Button("OK") {} } message: { Text(errorMessage ?? "") }
        }
    }

    private func save(_ snippets: [Snippet]) {
        do { try store.save(snippets) } catch { errorMessage = error.localizedDescription }
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
        self.snippet = snippet; self.onSave = onSave
        _trigger = State(initialValue: snippet.trigger); _expansionBody = State(initialValue: snippet.body); _enabled = State(initialValue: snippet.enabled ?? true)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("トリガー") { TextField(";mail", text: $trigger).textInputAutocapitalization(.never).autocorrectionDisabled() }
                Section { TextEditor(text: $expansionBody).frame(minHeight: 220); Text("改行はReturnで入力できます。\\nを書く必要はありません。\n本文: \(expansionBody.count) / 8000文字・\(expansionBody.isEmpty ? 0 : expansionBody.components(separatedBy: "\n").count)行").font(.caption).foregroundStyle(.secondary) } header: { Text("展開する文章") }
                Section { Toggle("このスニペットを有効にする", isOn: $enabled) }
            }
            .navigationTitle("辞書を編集")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("キャンセル") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("保存") { onSave(Snippet(id: snippet.id, trigger: trigger, body: expansionBody, enabled: enabled, tags: snippet.tags)) }.disabled(trigger.isEmpty || expansionBody.isEmpty) }
            }
        }
    }
}
