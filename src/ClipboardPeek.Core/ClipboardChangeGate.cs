using System;
using System.Runtime.InteropServices;
using System.Security.Cryptography;

namespace ClipboardPeek.Core;

/// <summary>
/// Tracks clipboard changes without retaining the clipboard's plain text.
/// The first observation establishes a baseline and cannot open the viewer.
/// </summary>
public sealed class ClipboardChangeGate
{
    private byte[]? _lastDigest;
    private ulong? _lastSequence;
    public bool IsPrimed { get; private set; }

    public bool HasUnchangedNativeSequence(ulong? sequence) =>
        IsPrimed && _lastSequence.HasValue && sequence.HasValue &&
        _lastSequence.Value == sequence.Value;

    /// <summary>
    /// Allows Windows to establish the startup clipboard identity immediately,
    /// before its first asynchronous text read completes.
    /// </summary>
    public void PrimeSequence(ulong sequence)
    {
        Reset();
        _lastSequence = sequence;
        IsPrimed = true;
    }

    public bool Observe(string? text, ulong? sequence)
    {
        byte[] digest = SHA256.HashData(
            MemoryMarshal.AsBytes((text ?? string.Empty).AsSpan(
                0, Math.Min(text?.Length ?? 0, PreviewState.MaximumCharacters))));

        bool hasChanged = IsPrimed &&
            ((_lastSequence.HasValue && sequence.HasValue && _lastSequence.Value != sequence.Value)
             || _lastDigest is not null &&
                !CryptographicOperations.FixedTimeEquals(_lastDigest, digest));

        if (_lastDigest is not null)
        {
            CryptographicOperations.ZeroMemory(_lastDigest);
        }

        _lastDigest = digest;
        _lastSequence = sequence;
        IsPrimed = true;

        // Nontext clipboard changes update the baseline without opening a text viewer.
        return hasChanged && !string.IsNullOrEmpty(text);
    }

    public void Reset()
    {
        if (_lastDigest is not null)
        {
            CryptographicOperations.ZeroMemory(_lastDigest);
            _lastDigest = null;
        }

        _lastSequence = null;
        IsPrimed = false;
    }
}
