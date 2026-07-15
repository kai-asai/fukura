namespace FukuraWindows;

internal sealed class SnippetMatcher
{
    private IReadOnlyList<Snippet> _snippets = [];
    private string _buffer = "";
    private int _maxTriggerLength;

    public void Update(IReadOnlyList<Snippet> snippets)
    {
        _snippets = snippets.OrderByDescending(item => item.Trigger.Length).ThenBy(item => item.Trigger).ToList();
        _maxTriggerLength = _snippets.Count == 0 ? 0 : _snippets.Max(item => item.Trigger.Length);
        Reset();
    }

    public Snippet? Push(string text)
    {
        if (_maxTriggerLength == 0) return null;
        _buffer += text;
        if (_buffer.Length > _maxTriggerLength) _buffer = _buffer[^_maxTriggerLength..];
        var match = _snippets.FirstOrDefault(item => _buffer.EndsWith(item.Trigger, StringComparison.Ordinal));
        if (match is not null) Reset();
        return match;
    }

    public void Reset() => _buffer = "";
}
