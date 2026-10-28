using System;
using System.Runtime.InteropServices;
using System.Security.Cryptography;

namespace ClipboardPeek.Core;

/// <summary>
/// Keeps only the latest bounded plaintext preview in process memory.
/// </summary>
public sealed class PreviewState
{
    public const int MaximumCharacters = 65_536;
    private const string TruncationNotice = "\n\n[Preview limited to 65,536 characters]";
    private byte[]? _lastObservedHash;

    public bool IsFrozen { get; private set; }
    public bool IsMasked { get; private set; }
    public string? CapturedText { get; private set; }

    public string DisplayText => IsMasked
        ? "Preview hidden. Select Show to reveal it."
        : CapturedText ?? "Copy text in another application to preview it here.";

    public bool Observe(string? clipboardText)
    {
        if (IsFrozen || string.IsNullOrEmpty(clipboardText))
        {
            return false;
        }

        string boundedText = clipboardText.Length > MaximumCharacters
            ? string.Concat(clipboardText.AsSpan(0, MaximumCharacters), TruncationNotice)
            : clipboardText;

        byte[] hash = SHA256.HashData(MemoryMarshal.AsBytes(boundedText.AsSpan()));
        if (_lastObservedHash is not null &&
            CryptographicOperations.FixedTimeEquals(hash, _lastObservedHash))
        {
            CryptographicOperations.ZeroMemory(hash);
            return false;
        }

        if (_lastObservedHash is not null)
        {
            CryptographicOperations.ZeroMemory(_lastObservedHash);
        }

        _lastObservedHash = hash;
        CapturedText = boundedText;
        return true;
    }

    public void SetFrozen(bool frozen) => IsFrozen = frozen;
    public void SetMasked(bool masked) => IsMasked = masked;

    public void Clear()
    {
        // Leave the change marker so the current clipboard does not reappear.
        CapturedText = null;
    }

    public void DisposeContent()
    {
        CapturedText = null;
        if (_lastObservedHash is not null)
        {
            CryptographicOperations.ZeroMemory(_lastObservedHash);
            _lastObservedHash = null;
        }
    }
}
