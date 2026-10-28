# Gold Standard release gates

Never claim that source inspection, static analysis, compilation, automated tests, native startup, screenshots, human visual quality and actual public downloads are interchangeable. Proof applies only to the exact source commit and published archive.

| Dimension | Release acceptance |
| --- | --- |
| Preservation | Audit repo and commit, no history rewrites, exact scope |
| Function | Plain text copy, freeze, hide, clear, unpin, move, resize, tint, close |
| Boundaries | Unicode, long text, rapid changes, empty clipboard, unavailable clipboard |
| Privacy | No clipboard logs, disk history, remote transport, tracking or hidden persistence |
| Stability | No unbounded process growth, blocked clipboard handling, normal exit and restart |
| Visual | 10%, 30% and 100% tint; readable text; DPI, monitors, compositors, mouse interactions |
| Accessibility | Keyboard use, discoverability, readable default contrast and controls |
| Performance | CPU/RAM measurements on a modest desktop; high text volume and idle poll |
| Windows | Compile and packaged PE validation plus actual Windows 10/11 manual GUI acceptance |
| Linux | Compile and virtual X display smoke plus manual X11 and supported Wayland inspection |
| Supply chain | Audit known dependency vulnerabilities, review IP notices, generate SHA256 digests |
| Public truth | Package names, README links and limitations match actual released behavior |
| Release | Human acceptance and exact candidate validation before authorized version tag |

The GitHub workflow performs build and core test execution on Windows and Linux, package audit, self contained publishing, Linux virtual display startup smoke and package digest checks. It does not claim the unrun manual visual, security, performance, Windows GUI or real user tests have passed.

Version tags beginning with `v` automatically create release archives after both build runners succeed. Do not create the stable version tag before manual acceptance. Keep the repository private until the owner approves public visibility and legal/IP checks.
