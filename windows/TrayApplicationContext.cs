using Microsoft.Win32;
using System.Diagnostics;

namespace FukuraWindows;

internal sealed class TrayApplicationContext : ApplicationContext
{
    private const string RunKeyPath = @"Software\Microsoft\Windows\CurrentVersion\Run";
    private const string ThemeKeyPath = @"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize";
    private const string RunValueName = "fukura";
    private const string LegacyRunValueName = "bon";
    private readonly SnippetStore _store = new();
    private readonly NotifyIcon _tray = new();
    private readonly Control _dispatcher = new();
    private readonly KeyboardExpander _expander;
    private readonly DictionaryForm _editor;
    private readonly ToolStripMenuItem _pauseItem = new("展開を一時停止");
    private readonly ToolStripMenuItem _startupItem = new("Windowsログイン時に起動");
    private Icon? _trayIcon;

    public TrayApplicationContext()
    {
        _dispatcher.CreateControl();
        MigrateLegacyStartupRegistration();
        _store.Load();
        _expander = new KeyboardExpander(_dispatcher);
        _expander.Update(_store.EnabledSnippets);
        _editor = new DictionaryForm(_store, () => _expander.Update(_store.EnabledSnippets));
        ConfigureTray();
        SystemEvents.UserPreferenceChanged += OnUserPreferenceChanged;
        _expander.Start();
        if (_store.WasCreatedOnLoad)
        {
            _dispatcher.BeginInvoke((Action)OpenEditor);
        }
    }

    private void ConfigureTray()
    {
        var menu = new ContextMenuStrip();
        menu.Items.Add("辞書を編集…", null, (_, _) => OpenEditor());
        menu.Items.Add("snippets.jsonをインポート…", null, (_, _) => ImportJson());
        menu.Items.Add("保存フォルダーを開く", null, (_, _) => Process.Start(new ProcessStartInfo("explorer.exe", _store.DirectoryPath) { UseShellExecute = true }));
        menu.Items.Add(new ToolStripSeparator());
        _pauseItem.Click += (_, _) => TogglePaused();
        menu.Items.Add(_pauseItem);
        _startupItem.Checked = IsStartupEnabled();
        _startupItem.Click += (_, _) => ToggleStartup();
        menu.Items.Add(_startupItem);
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add("終了", null, (_, _) => Exit());
        UpdateTrayIcon();
        _tray.Text = "fukura";
        _tray.ContextMenuStrip = menu;
        _tray.Visible = true;
        _tray.DoubleClick += (_, _) => OpenEditor();
    }

    private void OpenEditor()
    {
        if (_editor.Visible)
        {
            _editor.WindowState = FormWindowState.Normal;
            _editor.Activate();
            return;
        }
        _editor.ReloadFromStore();
        _editor.Show();
        _editor.WindowState = FormWindowState.Normal;
        _editor.Activate();
    }

    private void ImportJson()
    {
        using var dialog = new OpenFileDialog { Filter = "JSON ファイル|*.json", Multiselect = false };
        if (dialog.ShowDialog() != DialogResult.OK) return;
        try
        {
            _store.Import(dialog.FileName);
            _expander.Update(_store.EnabledSnippets);
            _editor.ReloadFromStore();
            _tray.ShowBalloonTip(2500, "fukura", $"{_store.EnabledSnippets.Count}件の有効なスニペットを読み込みました。", ToolTipIcon.Info);
        }
        catch (Exception error) { MessageBox.Show(error.Message, "インポートできません", MessageBoxButtons.OK, MessageBoxIcon.Error); }
    }

    private void TogglePaused()
    {
        _expander.SetPaused(!_expander.IsPaused);
        _pauseItem.Checked = _expander.IsPaused;
        _pauseItem.Text = _expander.IsPaused ? "展開を再開" : "展開を一時停止";
    }

    private static bool IsStartupEnabled()
    {
        using var key = Registry.CurrentUser.OpenSubKey(RunKeyPath);
        return key?.GetValue(RunValueName) is string;
    }

    private static Icon LoadTrayIcon()
    {
        using var themeKey = Registry.CurrentUser.OpenSubKey(ThemeKeyPath);
        var usesLightTaskbar = themeKey?.GetValue("SystemUsesLightTheme") is int value && value != 0;
        var fileName = usesLightTaskbar ? "fukura-tray-dark.ico" : "fukura-tray-light.ico";
        var assembly = typeof(TrayApplicationContext).Assembly;
        var resourceName = assembly.GetManifestResourceNames()
            .FirstOrDefault(name => name.EndsWith($".Resources.{fileName}", StringComparison.OrdinalIgnoreCase));
        if (resourceName is not null)
        {
            using var stream = assembly.GetManifestResourceStream(resourceName);
            if (stream is not null)
            {
                using var icon = new Icon(stream);
                return (Icon)icon.Clone();
            }
        }

        return Icon.ExtractAssociatedIcon(Application.ExecutablePath)
            ?? (Icon)SystemIcons.Application.Clone();
    }

    private static void MigrateLegacyStartupRegistration()
    {
        using var key = Registry.CurrentUser.CreateSubKey(RunKeyPath);
        if (key.GetValue(LegacyRunValueName) is not string) return;

        key.DeleteValue(LegacyRunValueName, false);
        if (key.GetValue(RunValueName) is null)
        {
            key.SetValue(RunValueName, $"\"{Application.ExecutablePath}\"");
        }
    }

    private void OnUserPreferenceChanged(object sender, UserPreferenceChangedEventArgs args)
    {
        if (_dispatcher.IsDisposed) return;
        try { _dispatcher.BeginInvoke((Action)UpdateTrayIcon); }
        catch (InvalidOperationException) { }
    }

    private void UpdateTrayIcon()
    {
        var nextIcon = LoadTrayIcon();
        var previousIcon = _trayIcon;
        _trayIcon = nextIcon;
        _tray.Icon = nextIcon;
        previousIcon?.Dispose();
    }

    private void ToggleStartup()
    {
        using var key = Registry.CurrentUser.CreateSubKey(RunKeyPath);
        if (_startupItem.Checked)
        {
            key.DeleteValue(RunValueName, false);
            _startupItem.Checked = false;
        }
        else
        {
            key.SetValue(RunValueName, $"\"{Application.ExecutablePath}\"");
            _startupItem.Checked = true;
        }
    }

    private void Exit()
    {
        _tray.Visible = false;
        SystemEvents.UserPreferenceChanged -= OnUserPreferenceChanged;
        _editor.CloseForExit();
        _expander.Dispose();
        _tray.Dispose();
        _trayIcon?.Dispose();
        _dispatcher.Dispose();
        ExitThread();
    }
}
