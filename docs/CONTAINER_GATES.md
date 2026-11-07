# Containerized release-candidate gates

This is a **maintainer build procedure**, not an end-user installation method. It does not use GitHub Actions and does not upload assets.

## Scope and prerequisites

- Clean, committed Git checkout of the exact candidate. The PowerShell driver rejects staged, unstaged, and untracked files without deleting them.
- Docker Desktop or another working local Docker daemon and Windows PowerShell / PowerShell 7.
- Network access to Microsoft's .NET 10 SDK container image, operating-system package repositories, and NuGet during the first build.
- Enough available disk and system memory for Docker. The container is restricted to **2 CPUs, 3 GiB memory, 256 processes**, with a **25-minute script timeout**. This is a runtime resource limit, not a hard disk quota or cost cap.
- Source files are copied from a whitelist in the Dockerfile. Git internals and local outputs are excluded from the build context.

From the repository root:

```powershell
powershell -File scripts/container-release.ps1
```

The driver creates `artifacts/container/<UTC timestamp>/` containing:

| File | Scope |
| --- | --- |
| `ClipboardPeek-win-x64.zip` | Cross-compiled Windows x64 candidate. Not native Windows GUI tested. |
| `ClipboardPeek-linux-x64.tar.gz` | Linux x64 candidate with Xvfb process-continuity smoke check. |
| `SHA256SUMS.txt` | Digests verified inside the container and again by PowerShell on the host. |
| `dependency-audit.json` | NuGet advisory scan evidence at build time. |
| `linux-gui-smoke.log` | Output from the actual Linux Xvfb startup probe. |
| `release-evidence.txt` | Source SHA, SDK, and explicit unrun manual gates. |

The candidate archives are **not published automatically**. A real Windows 10/11 native GUI run, Linux X11/Wayland user workflow checks, manual usability, accessibility, privacy, resource measurements, source provenance, dependency licenses, and screenshot accuracy still apply. Do not tag, sign off on, or upload a production release until those requirements are satisfied.

## Local negative controls

The contract tests do not need .NET or Docker. In a Linux shell with Bash:

```bash
bash scripts/test-container-gate-contract.sh
```

They validate shell syntax and confirm malformed source identifiers and missing output mounts are rejected. These are limited **harness tests**, not product tests.

## Environment limitations and truthfulness

The ChatGPT execution container used to author these scripts has Bash, Python, and Xvfb but does not have Docker, PowerShell, .NET, cached Avalonia packages, or access to external package downloads. The containerized build and PowerShell orchestration therefore have **not been executed here**. Their source hashes were verified against GitHub after upload, while the Bash syntax and two negative input tests were actually run locally.

No real executable, binary release asset, Windows runtime acceptance, or public availability is claimed. Never replace an unrun result with a PASS.
