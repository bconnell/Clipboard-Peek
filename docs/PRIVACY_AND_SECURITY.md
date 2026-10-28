# Privacy and security

Clipboard Peek reads plain text from the operating system clipboard and displays one current preview locally. There are no clipboard history files, analytics, network APIs, marketing email, remote fonts, session replay, telemetry, remote monitoring, subscription features or uploaded content.

| Data | Lifetime |
| --- | --- |
| Clipboard preview | Process memory until replaced, cleared, or closed |
| Change marker | SHA256 digest in process memory until replaced or closed |
| Actual system clipboard | Owned by the operating system and never modified by Clipboard Peek |

Hide masks the preview visually but retains content in memory. Freeze stops reading while active. Clear clears the local preview, not the system clipboard. This is not secure encryption or a secret management tool. Screen recording, shoulder surfing, crash dumps and local privileged access can expose copied secrets.

Input is rendered as text and not executed. Oversized plain text is bounded for display but may briefly allocate more when retrieved. Clipboard exceptions are handled without writing contents to logs. Windows and Linux desktop behavior depends on the compositor/window manager and security context. No administrator privileges are expected.

The MIT license covers the original project code. Third party notices and actual redistributable package rights need verification. COPPA and age data, cookies and tracking, consent, marketing email, recurring billing, uploads and copyright complaint handling are not active product features; reevaluate if the product adds them. Accessible use, honest claims, local privacy and compliant distribution remain release gates.
