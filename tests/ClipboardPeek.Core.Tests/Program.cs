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

ClipboardChangeGate gate = new();
Require(!gate.Observe("existing before launch", 101), "startup text does not show");
Require(gate.IsPrimed, "startup clipboard was primed");
Require(!gate.Observe("existing before launch", 101), "idle clipboard does not show");
Require(gate.Observe("new copy", 102), "new clipboard content shows");
Require(!gate.Observe("new copy", 102), "unchanged clipboard stays quiet");
Require(gate.Observe("new copy", 103), "copying identical text again shows on Windows");
Require(!gate.Observe(null, 104), "nontext clipboard does not show");
Require(gate.Observe("new copy", 105), "new text after a nontext item shows");
Require(!gate.Observe("new copy", null), "missing sequence uses text comparison");
Require(gate.Observe("different", null), "cross-platform text changes show");
gate.Reset();
Require(!gate.IsPrimed, "reset discards baseline");
Require(!gate.Observe("different", null), "post-reset first observation stays hidden");

ClipboardChangeGate earlyStartup = new();
earlyStartup.PrimeSequence(500);
Require(earlyStartup.HasUnchangedNativeSequence(500), "unchanged Windows clipboard needs no repeated read");
Require(!earlyStartup.HasUnchangedNativeSequence(501), "new Windows clipboard must be read");
Require(!earlyStartup.Observe("existing content", 500), "startup content stays hidden if sampled asynchronously");
Require(earlyStartup.Observe("copied immediately after launch", 501), "copy after immediate native baseline opens viewer");
earlyStartup.Reset();
Require(!earlyStartup.IsPrimed, "immediate startup baseline resets");

PreviewState repeatedCopy = new();
Require(repeatedCopy.Observe("same text"), "first preview copy captured");
repeatedCopy.Clear();
Require(!repeatedCopy.Observe("same text"), "clear suppresses idle redisplay");
Require(repeatedCopy.Observe("same text", force: true), "explicit second copy restores cleared text");
Require(repeatedCopy.DisplayText == "same text", "repeated copy is readable");
repeatedCopy.DisposeContent();

Console.WriteLine("All ClipboardPeek core tests passed.");
