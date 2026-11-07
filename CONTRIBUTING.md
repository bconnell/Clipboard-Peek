# Contributing

Clipboard Peek is a small, MIT-licensed C# / Avalonia desktop utility. Contributions should solve a demonstrated issue without adding unnecessary infrastructure or collecting user data.

## Before proposing changes

1. Check existing issues and reproduce the behavior using synthetic clipboard text.
2. Make one focused change and keep the overlay usable, movable, readable, local-only, and recoverable from the system tray.
3. Follow the existing project style and add regression coverage for changed behavior, including failure and recovery cases where relevant.
4. Build and run the core tests using .NET 10. If relevant, exercise the actual Windows or Linux GUI; explain which platforms and display systems you tested.
5. Never commit binaries, copied clipboard contents, credentials, local logs, generated build outputs, private screenshots, or unrelated files.

Open a normal pull request describing the problem, the fix, local validation evidence, accessibility implications, and remaining untested behavior. Do not claim passed checks that were not executed. Existing local release scripts and documented acceptance gates remain authoritative while hosted Actions is unavailable.

Security concerns should follow [SECURITY.md](SECURITY.md), not public disclosure with sensitive examples.

Please keep contribution and authorship credits accurate. Add coauthor attribution only for genuine, authorized collaborative work. Do not manufacture commits, reviews, issue activity, or badge triggers.
