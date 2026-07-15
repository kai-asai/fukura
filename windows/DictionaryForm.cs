using System.Diagnostics;

namespace FukuraWindows;

internal sealed class DictionaryForm : Form
{
    private readonly SnippetStore _store;
    private readonly Action _saved;
    private readonly ListBox _list = new() { Dock = DockStyle.Fill, IntegralHeight = false };
    private readonly TextBox _search = new() { PlaceholderText = "トリガー・本文を検索" };
    private readonly TextBox _trigger = new() { PlaceholderText = ";mail" };
    private readonly TextBox _body = new() { Multiline = true, AcceptsReturn = true, AcceptsTab = true, ScrollBars = ScrollBars.Vertical, Font = new Font("Yu Gothic UI", 10) };
    private readonly CheckBox _enabled = new() { Text = "このスニペットを有効にする", AutoSize = true };
    private readonly Label _count = new() { AutoSize = true, ForeColor = SystemColors.GrayText };
    private readonly Label _status = new() { AutoSize = true, ForeColor = SystemColors.GrayText };
    private readonly Button _save = new() { Text = "保存", AutoSize = true, Enabled = false };
    private List<Snippet> _snippets = [];
    private Snippet? _selected;
    private bool _dirty;
    private bool _loading;
    private bool _allowClose;

    public DictionaryForm(SnippetStore store, Action saved)
    {
        _store = store;
        _saved = saved;
        Text = "スニペット辞書 - fukura";
        Width = 940;
        Height = 650;
        MinimumSize = new Size(760, 520);
        StartPosition = FormStartPosition.CenterScreen;
        Font = new Font("Yu Gothic UI", 9);
        BuildUi();
        ReloadFromStore();
    }

    public void ReloadFromStore()
    {
        _snippets = _store.Document.Snippets.Select(item => new Snippet
        {
            Id = item.Id, Trigger = item.Trigger, Body = item.Body, Enabled = item.Enabled,
            Tags = item.Tags is null ? null : [.. item.Tags], UpdatedAt = item.UpdatedAt
        }).ToList();
        _dirty = false;
        _status.Text = "";
        RefreshList();
    }

    private void BuildUi()
    {
        var split = new SplitContainer { Dock = DockStyle.Fill, SplitterDistance = 285, FixedPanel = FixedPanel.Panel1 };
        Controls.Add(split);

        var sidebar = new TableLayoutPanel { Dock = DockStyle.Fill, Padding = new Padding(12), RowCount = 3, ColumnCount = 1 };
        sidebar.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        sidebar.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        sidebar.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        sidebar.Controls.Add(_search, 0, 0);
        sidebar.Controls.Add(_list, 0, 1);
        var sideActions = new FlowLayoutPanel { AutoSize = true, Dock = DockStyle.Fill, FlowDirection = FlowDirection.LeftToRight };
        var add = new Button { Text = "＋ 追加", AutoSize = true };
        var duplicate = new Button { Text = "複製", AutoSize = true };
        var delete = new Button { Text = "削除", AutoSize = true };
        sideActions.Controls.AddRange([add, duplicate, delete]);
        sidebar.Controls.Add(sideActions, 0, 2);
        split.Panel1.Controls.Add(sidebar);

        var detail = new TableLayoutPanel { Dock = DockStyle.Fill, Padding = new Padding(28, 22, 28, 18), RowCount = 9, ColumnCount = 1 };
        detail.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        detail.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        detail.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        detail.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        detail.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        detail.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        detail.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        detail.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        detail.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        var title = new Label { Text = "辞書を編集", AutoSize = true, Font = new Font(Font.FontFamily, 17, FontStyle.Bold), Margin = new Padding(0, 0, 0, 5) };
        var hint = new Label { Text = "展開する文章はそのまま入力できます。改行は Enter キーで入力し、\\n のような記号を書く必要はありません。", AutoSize = true, ForeColor = SystemColors.GrayText, Margin = new Padding(0, 0, 0, 18) };
        var triggerLabel = new Label { Text = "トリガー", AutoSize = true, Font = new Font(Font, FontStyle.Bold) };
        var bodyLabel = new Label { Text = "展開する文章", AutoSize = true, Font = new Font(Font, FontStyle.Bold), Margin = new Padding(0, 14, 0, 3) };
        var footer = new FlowLayoutPanel { Dock = DockStyle.Fill, AutoSize = true, FlowDirection = FlowDirection.RightToLeft };
        var revert = new Button { Text = "変更を戻す", AutoSize = true };
        var export = new Button { Text = "JSONを書き出す…", AutoSize = true };
        footer.Controls.AddRange([_save, revert, export, _status]);
        _trigger.Dock = DockStyle.Top;
        _body.Dock = DockStyle.Fill;
        detail.Controls.Add(title, 0, 0);
        detail.Controls.Add(hint, 0, 1);
        detail.Controls.Add(triggerLabel, 0, 2);
        detail.Controls.Add(_trigger, 0, 3);
        detail.Controls.Add(bodyLabel, 0, 4);
        detail.Controls.Add(_body, 0, 5);
        detail.Controls.Add(_count, 0, 6);
        detail.Controls.Add(_enabled, 0, 7);
        detail.Controls.Add(footer, 0, 8);
        split.Panel2.Controls.Add(detail);

        _search.TextChanged += (_, _) => RefreshList(_selected);
        _list.SelectedIndexChanged += (_, _) => SelectSnippet(_list.SelectedItem as Snippet);
        _trigger.TextChanged += (_, _) => FieldChanged();
        _body.TextChanged += (_, _) => FieldChanged();
        _enabled.CheckedChanged += (_, _) => FieldChanged();
        add.Click += (_, _) => AddSnippet();
        duplicate.Click += (_, _) => DuplicateSnippet();
        delete.Click += (_, _) => DeleteSnippet();
        _save.Click += (_, _) => SaveChanges();
        revert.Click += (_, _) => { if (!_dirty || ConfirmDiscard()) ReloadFromStore(); };
        export.Click += (_, _) => ExportJson();
        FormClosing += OnFormClosing;
        KeyPreview = true;
        KeyDown += (_, args) => { if (args.Control && args.KeyCode == Keys.S) { SaveChanges(); args.SuppressKeyPress = true; } };
    }

    private void RefreshList(Snippet? preferred = null)
    {
        var query = _search.Text.Trim();
        var visible = _snippets.Where(item => query.Length == 0 || item.Trigger.Contains(query, StringComparison.OrdinalIgnoreCase) || item.Body.Contains(query, StringComparison.OrdinalIgnoreCase)).ToList();
        _loading = true;
        _list.BeginUpdate();
        _list.Items.Clear();
        _list.Items.AddRange(visible.Cast<object>().ToArray());
        _list.EndUpdate();
        _loading = false;
        if (preferred is not null && visible.Contains(preferred)) _list.SelectedItem = preferred;
        else if (_list.Items.Count > 0) _list.SelectedIndex = 0;
        else SelectSnippet(null);
    }

    private void SelectSnippet(Snippet? snippet)
    {
        if (_loading) return;
        CommitFields();
        _selected = snippet;
        _loading = true;
        _trigger.Text = snippet?.Trigger ?? "";
        _body.Text = snippet?.Body ?? "";
        _enabled.Checked = snippet?.Enabled ?? false;
        _loading = false;
        var active = snippet is not null;
        _trigger.Enabled = active;
        _body.Enabled = active;
        _enabled.Enabled = active;
        UpdateCount();
    }

    private void CommitFields()
    {
        if (_loading || _selected is null) return;
        _selected.Trigger = _trigger.Text;
        _selected.Body = _body.Text;
        _selected.Enabled = _enabled.Checked;
    }

    private void FieldChanged()
    {
        if (_loading) return;
        CommitFields();
        _dirty = true;
        _save.Enabled = true;
        _status.Text = "未保存の変更があります";
        _list.Refresh();
        UpdateCount();
    }

    private void UpdateCount() => _count.Text = $"本文: {_body.Text.Length} / {SnippetStore.MaxBodyLength} 文字・{(_body.Text.Length == 0 ? 0 : _body.Lines.Length)} 行";

    private void AddSnippet()
    {
        if (_snippets.Count >= SnippetStore.MaxSnippets) return;
        var number = _snippets.Count + 1;
        string trigger;
        do { trigger = $";new{number++}"; } while (_snippets.Any(item => item.Trigger == trigger));
        var snippet = new Snippet { Id = Guid.NewGuid().ToString("N"), Trigger = trigger, Body = "ここに展開する文章を入力", Enabled = true };
        _snippets.Add(snippet);
        _dirty = true;
        _search.Clear();
        RefreshList(snippet);
        _trigger.Focus();
        _trigger.SelectAll();
        _save.Enabled = true;
    }

    private void DuplicateSnippet()
    {
        if (_selected is null || _snippets.Count >= SnippetStore.MaxSnippets) return;
        CommitFields();
        var number = 2;
        string trigger;
        do { trigger = $"{_selected.Trigger}-{number++}"; } while (_snippets.Any(item => item.Trigger == trigger));
        var copy = _selected.Clone(trigger);
        _snippets.Insert(_snippets.IndexOf(_selected) + 1, copy);
        _dirty = true;
        _search.Clear();
        RefreshList(copy);
        _save.Enabled = true;
    }

    private void DeleteSnippet()
    {
        if (_selected is null) return;
        if (MessageBox.Show($"「{_selected.Trigger}」を削除しますか？\n保存するまでファイルには反映されません。", "スニペットを削除", MessageBoxButtons.OKCancel, MessageBoxIcon.Warning) != DialogResult.OK) return;
        _snippets.Remove(_selected);
        _selected = null;
        _dirty = true;
        RefreshList();
        _save.Enabled = true;
    }

    private void SaveChanges()
    {
        CommitFields();
        try
        {
            _store.Save(_snippets);
            _dirty = false;
            _save.Enabled = false;
            _status.Text = "保存しました（バックアップも更新済み）";
            _saved();
        }
        catch (Exception error) { MessageBox.Show(error.Message, "保存できません", MessageBoxButtons.OK, MessageBoxIcon.Error); }
    }

    private void ExportJson()
    {
        SaveChanges();
        if (_dirty) return;
        using var dialog = new SaveFileDialog { Filter = "JSON ファイル|*.json", FileName = "snippets.json", OverwritePrompt = true };
        if (dialog.ShowDialog(this) == DialogResult.OK)
        {
            try { _store.Export(dialog.FileName); }
            catch (Exception error) { MessageBox.Show(error.Message, "書き出せません", MessageBoxButtons.OK, MessageBoxIcon.Error); }
        }
    }

    private bool ConfirmDiscard() => MessageBox.Show("未保存の変更を破棄しますか？", "変更を破棄", MessageBoxButtons.OKCancel, MessageBoxIcon.Warning) == DialogResult.OK;

    private void OnFormClosing(object? sender, FormClosingEventArgs args)
    {
        if (_allowClose) return;
        if (_dirty && !ConfirmDiscard()) { args.Cancel = true; return; }
        args.Cancel = true;
        Hide();
    }

    public void CloseForExit() { _allowClose = true; Close(); }
}
