# Architecture

The C# core library owns exactly one in memory preview, its local SHA256 change marker, freeze, mask and clear semantics. It has no network, file, application discovery, account or history dependency.

The Avalonia window owns the topmost overlay, background tint, text rendering, buttons, resize/move interactions and a 700 ms clipboard poll. Only the background surface is semi transparent. The foreground text retains full opacity.

The operating system clipboard is authoritative. Clipboard Peek is a read only process local projection. Clear intentionally suppresses redisplay of the last observed clipboard string, but does not change system clipboard contents. Freezing intentionally retains the older preview. The displayed content is capped at 65,536 characters after clipboard retrieval; the clipboard API may temporarily allocate larger payloads.

Closing drops application references to copied content. Managed string memory cannot be guaranteed securely erased.

Native click through, system tray, global hotkeys, autostart, persistence, cloud sync and mobile support are outside the initial release scope and require separate safety, platform and accessibility review.
