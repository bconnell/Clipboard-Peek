# Native release acceptance

This checklist is **not evidence of a pass**. Every checkbox starts unverified. Record the exact Git SHA, archive SHA256, OS build, windowing system, display scale, hardware, operator, date, screenshots and observed failures for each test. Do not store copied private or customer content in evidence. Use synthetic clipboard text. Keep screenshot contents within the application under test and relevant background context, excluding taskbars and private desktop elements.

## Windows 10/11, x64

- [ ] Release script exits zero on an unchanged clean checkout. Hash matches archive.
- [ ] Archive extracts into a fresh ordinary user directory. No SDK or admin access required.
- [ ] `ClipboardPeek.exe` starts with no file missing or runtime error; works after restart.
- [ ] A 30% dark background tint lets background application content show through while preview text remains opaque.
- [ ] Tint slider moves through 10%, 30%, 100%; background changes but text contrast remains usable.
- [ ] Copy text from browser, text editor, file dialog and another ordinary app. Changes appear without pasting.
- [ ] Switch between apps repeatedly. Preview remains topmost while pinned; unpin changes z-order.
- [ ] Drag the top bar, resize from the lower right, close and relaunch without trapping the window offscreen.
- [ ] Freeze prevents clipboard replacement; Resume updates from the actual current clipboard.
- [ ] Hide masks current preview and subsequent copied content; Show reveals the current content.
- [ ] Clear does not erase the OS clipboard and suppresses redisplay until different clipboard text appears.
- [ ] Test empty clipboard, plain Unicode, emoji, tabs, newlines, large content and rapid copy changes.
- [ ] The viewer can be navigated using a keyboard only; every action remains discoverable and visibly focused.
- [ ] Test 100%, 125%, 150%, 200% scaling; small screens, multi-monitor move, and a high contrast background.
- [ ] Run while idle and while copying repeatedly on an 8 GB or lower memory class machine. Record CPU, RAM and any errors.
- [ ] Window close releases process, with no leftover service, auto start entry, application clipboard history or network transmission.
- [ ] Test locked desktop, sleep/resume and clipboard temporarily held by another process. No freeze or crash.

## Linux desktop, x64

- [ ] Local Linux script exits zero. ELF header, SHA256 and Xvfb startup check agree with archive.
- [ ] Extract archive with ordinary user permissions; binary launches without requiring dotnet SDK.
- [ ] On an actual X11 desktop, reproduce the clipboard, tint, freeze, hide, clear, topmost, move and resize scenarios above.
- [ ] Test on a modern Wayland session. Record whether the compositor supports transparency, positioning and clipboard monitoring. Do not claim support without actual evidence.
- [ ] Exercise keyboard-only use, multiple monitors, display scaling, font fallback and accessible controls.
- [ ] Record actual idle CPU/memory and responsiveness while switching apps on modest hardware.
- [ ] Exit, restart and ensure no background service, unexpected file, telemetry or unbounded retained copied text.

## Release authority

- [ ] Scan transitive dependencies for known advisories with an up to date feed; record and resolve any findings.
- [ ] Confirm all redistribution rights, MIT attribution and required third party notices in the actual packages.
- [ ] Verify no copyrighted third party assets, embedded credentials, personal data or hidden network dependencies.
- [ ] Confirm zero advertisements, tracking, age-related collection, subscriptions, marketing email, uploads and session replay. Reopen legal gates if scope changes.
- [ ] Verify source commit and both archive hashes against signed off evidence. Retest after every relevant change.
- [ ] Approve public repo visibility and attach both approved archives to an explicitly versioned GitHub Release.
- [ ] Check the public README downloads **actually resolve** for a regular unauthenticated user.
- [ ] Never label an unrun or unsupported test as PASS.

User eye review is mandatory: a script proving the executable remained alive is not proof that its controls are usable or its overlay is legible.
