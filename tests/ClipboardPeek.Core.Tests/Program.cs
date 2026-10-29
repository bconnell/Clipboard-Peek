using System;
using ClipboardPeek.Core;

static void Require(bool condition, string description)
{
    if (!condition)
    {
        throw new InvalidOperationException($"Failed: {description}");
    }
}

PreviewState preview = new();
Require(preview.CapturedText is null, "preview starts empty");
Require(!preview.Observe(null), "null clipboard is ignored");
Require(!preview.Observe(string.Empty), "empty clipboard is ignored");
Require(preview.Observe("123 Main Street"), "new text is captured");
Require(!preview.Observe("123 Main Street"), "same text does not refresh");

preview.SetFrozen(true);
Require(!preview.Observe("secret"), "frozen preview ignores changes");
Require(preview.DisplayText == "123 Main Street", "frozen text remains visible");
preview.SetFrozen(false);
Require(preview.Observe("revised"), "resume accepts changed text");

preview.SetMasked(true);
Require(!preview.DisplayText.Contains("revised", StringComparison.Ordinal), "mask conceals text");
Require(preview.Observe("new masked text"), "mask still allows monitoring");
Require(!preview.DisplayText.Contains("new masked text", StringComparison.Ordinal), "mask conceals newly copied text");
preview.SetMasked(false);
Require(preview.DisplayText == "new masked text", "unmask restores latest text");

preview.Clear();
Require(preview.CapturedText is null, "clear removes preview");
Require(!preview.Observe("new masked text"), "clear does not redisplay same clipboard text");
Require(preview.Observe("new copy"), "new clipboard content appears after clear");
Require(preview.Observe("multi\nline\ttext 😀"), "multiline Unicode text accepted");
Require(preview.DisplayText.Contains("😀", StringComparison.Ordinal), "Unicode preserved");

string largeText = new('x', PreviewState.MaximumCharacters + 100);
Require(preview.Observe(largeText), "large text is captured with a display limit");
Require(preview.CapturedText!.Length < largeText.Length, "preview limits displayed size");
Require(preview.CapturedText.Contains("limited", StringComparison.Ordinal), "visible truncation warning");
preview.DisposeContent();
Require(preview.CapturedText is null, "close clears preview reference");
Require(preview.Observe("new session"), "core model can be reused after disposal");

Console.WriteLine("All ClipboardPeek core tests passed.");
