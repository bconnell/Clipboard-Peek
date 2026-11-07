# Security policy

Clipboard Peek is a local desktop utility that reads clipboard text. Copied text can include passwords, tokens, customer records, or other sensitive material, so privacy and safe issue reporting are important.

## Reporting a vulnerability

If GitHub's **Private vulnerability reporting** option is enabled for this repository, use **Security → Report a vulnerability**. Otherwise, open a minimal GitHub issue requesting a private reporting channel, without publishing vulnerability details or sensitive data.

Never include real clipboard contents, secrets, customer information, private desktop screenshots, credential-bearing logs, or exploit material in a public issue or pull request. Use synthetic examples.

## Current security boundaries

- The application is designed for local-only use. It does not send clipboard data to a service.
- A hidden or masked preview is not encrypted. Text may remain in process memory until replaced, cleared, or the process exits.
- Clearing Clipboard Peek does not erase the operating system clipboard.
- The window may be captured by screen sharing or recording software.
- Clipboard monitoring is not a password-manager or secure-secret-handling feature.
- There is no published stable, packaged release yet. Source changes require platform-specific runtime verification before release.

See [Privacy and security](docs/PRIVACY_AND_SECURITY.md) and [Release gates](docs/RELEASE_GATES.md) for behavior and acceptance scope.
