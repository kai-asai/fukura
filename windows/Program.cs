using System.Diagnostics;

namespace FukuraWindows;

internal static class Program
{
    [STAThread]
    private static void Main()
    {
        using var mutex = new Mutex(true, "Local\\FukuraWindows", out var isFirstInstance);
        if (!isFirstInstance)
        {
            MessageBox.Show("fukura はすでに起動しています。タスクトレイを確認してください。", "fukura");
            return;
        }

        var legacyProcesses = Process.GetProcessesByName("bon");
        try
        {
            if (legacyProcesses.Length > 0)
            {
                var response = MessageBox.Show(
                    "旧bonが起動中です。二重展開を防ぐためbonを終了してfukuraを起動しますか？",
                    "旧bonを終了します",
                    MessageBoxButtons.YesNo,
                    MessageBoxIcon.Warning
                );
                if (response != DialogResult.Yes) return;

                foreach (var process in legacyProcesses)
                {
                    try
                    {
                        process.Kill(entireProcessTree: true);
                        if (!process.WaitForExit(2000))
                            throw new InvalidOperationException("2秒以内に終了しませんでした。");
                    }
                    catch (Exception error)
                    {
                        MessageBox.Show(
                            $"bonを終了できません。タスクトレイからbonを終了し、fukuraを再起動してください。\n\n{error.Message}",
                            "fukuraの起動を中止しました",
                            MessageBoxButtons.OK,
                            MessageBoxIcon.Error
                        );
                        return;
                    }
                }
            }
        }
        finally
        {
            foreach (var process in legacyProcesses) process.Dispose();
        }
        ApplicationConfiguration.Initialize();
        try { Application.Run(new TrayApplicationContext()); }
        catch (Exception error)
        {
            MessageBox.Show(error.Message, "fukura を起動できません", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
    }
}
