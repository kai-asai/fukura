using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;

namespace FukuraWindows;

internal sealed class KeyboardExpander : IDisposable
{
    private const int WhKeyboardLl = 13;
    private const int WmKeyDown = 0x0100;
    private const int WmSysKeyDown = 0x0104;
    private const uint LlkhfInjected = 0x10;
    private readonly SnippetMatcher _matcher = new();
    private readonly LowLevelKeyboardProc _callback;
    private readonly Control _dispatcher;
    private IntPtr _hook;
    private bool _paused;
    private bool _replacing;

    public KeyboardExpander(Control dispatcher)
    {
        _dispatcher = dispatcher;
        _callback = HookCallback;
    }

    public bool IsPaused => _paused;

    public void Update(IReadOnlyList<Snippet> snippets) => _matcher.Update(snippets);

    public void Start()
    {
        using var process = Process.GetCurrentProcess();
        using var module = process.MainModule;
        _hook = SetWindowsHookEx(WhKeyboardLl, _callback, GetModuleHandle(module?.ModuleName), 0);
        if (_hook == IntPtr.Zero) throw new InvalidOperationException("キーボード監視を開始できませんでした。");
    }

    public void SetPaused(bool paused)
    {
        _paused = paused;
        _matcher.Reset();
    }

    private IntPtr HookCallback(int code, IntPtr message, IntPtr data)
    {
        if (code >= 0 && !_paused && !_replacing && (message == WmKeyDown || message == WmSysKeyDown))
        {
            var info = Marshal.PtrToStructure<KbdLlHookStruct>(data);
            if ((info.Flags & LlkhfInjected) == 0)
            {
                var key = (Keys)info.VirtualKeyCode;
                if ((Control.ModifierKeys & (Keys.Control | Keys.Alt | Keys.LWin | Keys.RWin)) != Keys.None)
                {
                    _matcher.Reset();
                }
                else if (key is Keys.Back or Keys.Delete or Keys.Left or Keys.Right or Keys.Up or Keys.Down or Keys.Escape or Keys.Tab or Keys.Enter)
                {
                    _matcher.Reset();
                }
                else
                {
                    var text = TranslateKey(info.VirtualKeyCode, info.ScanCode);
                    if (text.Length == 1 && _matcher.Push(text) is { } snippet)
                    {
                        _dispatcher.BeginInvoke((Action)(() => Replace(snippet)));
                    }
                }
            }
        }
        return CallNextHookEx(_hook, code, message, data);
    }

    private void Replace(Snippet snippet)
    {
        _replacing = true;
        IDataObject? previousClipboard = null;
        try
        {
            try { previousClipboard = Clipboard.GetDataObject(); } catch { }
            SendKeys.SendWait(string.Concat(Enumerable.Repeat("{BACKSPACE}", snippet.Trigger.Length)));
            Clipboard.SetText(snippet.Body);
            SendKeys.SendWait("^v");
        }
        finally
        {
            if (previousClipboard is not null)
            {
                var timer = new System.Windows.Forms.Timer { Interval = 250 };
                timer.Tick += (_, _) =>
                {
                    timer.Stop();
                    timer.Dispose();
                    try { Clipboard.SetDataObject(previousClipboard, true); } catch { }
                };
                timer.Start();
            }
            _replacing = false;
        }
    }

    private static string TranslateKey(uint virtualKey, uint scanCode)
    {
        var keyboardState = new byte[256];
        if (!GetKeyboardState(keyboardState)) return "";
        var buffer = new StringBuilder(8);
        var foregroundThread = GetWindowThreadProcessId(GetForegroundWindow(), IntPtr.Zero);
        var layout = GetKeyboardLayout(foregroundThread);
        var count = ToUnicodeEx(virtualKey, scanCode, keyboardState, buffer, buffer.Capacity, 0, layout);
        return count == 1 ? buffer.ToString() : "";
    }

    public void Dispose()
    {
        if (_hook != IntPtr.Zero) UnhookWindowsHookEx(_hook);
        _hook = IntPtr.Zero;
    }

    private delegate IntPtr LowLevelKeyboardProc(int code, IntPtr message, IntPtr data);

    [StructLayout(LayoutKind.Sequential)]
    private struct KbdLlHookStruct
    {
        public uint VirtualKeyCode;
        public uint ScanCode;
        public uint Flags;
        public uint Time;
        public UIntPtr ExtraInfo;
    }

    [DllImport("user32.dll", SetLastError = true)] private static extern IntPtr SetWindowsHookEx(int hook, LowLevelKeyboardProc callback, IntPtr module, uint threadId);
    [DllImport("user32.dll", SetLastError = true)] private static extern bool UnhookWindowsHookEx(IntPtr hook);
    [DllImport("user32.dll")] private static extern IntPtr CallNextHookEx(IntPtr hook, int code, IntPtr message, IntPtr data);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)] private static extern IntPtr GetModuleHandle(string? moduleName);
    [DllImport("user32.dll")] private static extern bool GetKeyboardState(byte[] keyboardState);
    [DllImport("user32.dll")] private static extern IntPtr GetKeyboardLayout(uint threadId);
    [DllImport("user32.dll")] private static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr window, IntPtr processId);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] private static extern int ToUnicodeEx(uint virtualKey, uint scanCode, byte[] keyboardState, [Out] StringBuilder buffer, int bufferSize, uint flags, IntPtr layout);
}
