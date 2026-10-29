# Clipboard Peek

A small, see through clipboard viewer for desktop computers. Copy plain text, switch to another app and read it without pasting. The floating overlay has a **30% default background tint**, adjustable from **10% to 100%**, and keeps its text opaque.

## Download Clipboard Peek

| Platform | Download | Run |
| --- | --- | --- |
| **Windows 10/11, 64 bit** | **Not yet available** | Planned: extract `ClipboardPeek-win-x64.zip`, then run `ClipboardPeek.exe`. |
| **Linux desktop, 64 bit** | **Not yet available** | Planned: extract `ClipboardPeek-linux-x64.tar.gz`, then run `./ClipboardPeek`. |

**No downloadable executables have been published.** The first release is blocked pending successful native compilation, dependency review, packaged runtime testing, and manual GUI acceptance. The release candidate is in [draft pull request #1](https://github.com/bconnell/Clipboard-Peek/pull/1). The planned archives are self contained and should not require users to install the .NET runtime. Once both files have actually been uploaded to a versioned GitHub Release and their checksums verified, this table must be updated to point directly to those specific assets.

Unsigned Windows executables may receive a SmartScreen warning. Do not bypass an unfamiliar warning without checking the source and publisher. Linux needs compatible desktop graphics libraries and a compositor.

## How it works

1. Launch Clipboard Peek. It stays above other apps by default.
2. Copy text in another application. The latest copied plain text appears in the floating window.
3. Drag the title to move the window, drag the lower corner to resize, and use the Tint slider to see more of the window underneath.
4. **Freeze** holds the current preview while other text is copied. **Hide** masks the preview. **Clear** discards the current preview. **Unpin** disables always on top. **×** exits.

Clipboard Peek never pastes text, edits the system clipboard, saves a clipboard history, or uploads copied content. There are no user accounts, telemetry, advertisements or cloud features.

### Know the limitations

- A transparent overlay is **not click through**. Mouse clicks still interact with the viewer. Native click through is not part of this release.
- **Hide** masks the displayed text but still allows clipboard updates and keeps the latest text in application memory. Use **Freeze** or close the program before copying secrets.
- **Clear** clears the preview only, not the system clipboard. It suppresses the current text until different clipboard text is observed.
- The viewer displays at most 65,536 copied characters, with a visible truncation message. The clipboard read can temporarily allocate a larger string.
- The viewer polls roughly every 700 milliseconds. Exact clipboard events, including recopies of identical text, cannot always be distinguished.
- Transparency, clipboard permission and rendering can vary across Linux desktops and Wayland environments. Human acceptance on the exact supported desktop is required.
- The current packages target Windows x64 and Linux x64, not macOS or phones.

## Build from source

Requires **.NET 10 SDK** and NuGet access. UI uses **Avalonia 12.1.4**.

```bash
dotnet run --project src/ClipboardPeek/ClipboardPeek.csproj
dotnet run --project tests/ClipboardPeek.Core.Tests/ClipboardPeek.Core.Tests.csproj
```

For a standalone Linux 64 bit publish:

```bash
dotnet publish src/ClipboardPeek/ClipboardPeek.csproj -c Release -r linux-x64 --self-contained true -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true
```

Use `win-x64` to target Windows. Cross compilation is not native runtime verification.

**Local release gates:** On Windows, run `powershell -File scripts/release-local-windows.ps1` from a clean clone. On Linux, run `bash scripts/release-local-linux.sh`. Both gates require a .NET 10 SDK, clean Git checkout, dependency audit, adequate RAM and disk space, and create a verifiable archive under `artifacts/local/`. Linux additionally requires `xvfb-run` for a virtual display smoke check. Windows GUI and Linux compositor interaction still require manual acceptance. No tool or framework is silently installed. Do not change machine security policy to run unverified source.

The optional [build and release workflow](.github/workflows/build-and-release.yml) executes core tests, application builds, package vulnerability checks, a Linux virtual display startup probe, packaging and SHA256 verification. When GitHub Actions becomes available, a manually dispatched workflow on an authorized version tag can create a release **only after** both build jobs succeed. Hosted Actions is currently unavailable, so local native release gates are required. Automated checks do not replace Windows GUI acceptance or human visual, resource, accessibility and Linux compositor testing. See the [release gates](docs/RELEASE_GATES.md).

## Documentation

[Architecture](docs/ARCHITECTURE.md) · [Privacy and security](docs/PRIVACY_AND_SECURITY.md) · [Release gates](docs/RELEASE_GATES.md) · [Native acceptance checklist](docs/MANUAL_ACCEPTANCE.md) · [Third party notices](THIRD_PARTY_NOTICES.md)

## License

[MIT License](LICENSE). Copyright 2026 Brandon Connell.
