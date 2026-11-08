# KillBill professionalization ledger

Plan: OpenChamber plan 3f2dd9da-614f-4683-8d78-775f4d835301.
User approved implementation in an isolated worktree and build/focused tests.
No commit, push, app installation or live update authorized.

## Decisions
- Preserve SwiftUI/AppKit and macOS 13 support.
- Existing force-default preference is retained, but every label and action must agree.
- Automatic inactivity closure stays unavailable until its separate later-release scope is implemented; remove the misleading enabled control.
- Future profiles and history are not first-release requirements.
- Signing/notarization requires the user's distribution credentials; support an explicit signing identity in packaging, never invent one.
- No .trail directory in this checkout; no Trail initialization performed.
- Tests use isolated defaults and fake process operations, never terminate real user apps.
- Global instructions override automatic commit and skill test-run rules; only approved tests/builds run.

## Progress
- Implementation started. Six plan stages pending.
- 1. Quit behavior: normal default for new users; single policy; protected apps; real termination tracking with 15s timeout; force confirmation; sounds restored; global shortcut path uses normal/force as named.
- 2. Settings/keyboard: ⌘A recordable (UInt32.max sentinel), Escape/Delete handling, conflict surfaced in UI, login-item errors surfaced, reset refreshes memory and persists, grouping/Finder/system color/tips/Trash now effective, misleading auto-quit control removed.
- 3. UI: 380pt panel with clear header, search/sort, empty vs no-results states, CPU alignment, larger rows, lock affordance, result details; preferences tabs Genel/Kapatma/Kısayollar/Güncelleme/Hakkında; native About; reset confirmation; help links now KillBill.
- 4. Updates: source/package pinned after check, HTTPS redirect guard, strict ZIP parser (symlink/encryption/multi-disk/size/path), required version.json and identity, Developer ID team enforcement for remote/update, in-place staging with rollback, launch health check and automatic restore, Keychain token, error-path temp cleanup, UI mutation on main.
- 5. Monitoring: CPU sampling only while panel visible, NSWorkspace launch/terminate observers, no reset of last CPU, one-shot local key monitor owned by the panel model.
- 6. Packaging/docs: both scripts use version.json, build_pkg reuses build_app, signing identity optional and failures not swallowed, installer conclusion simplified, README rewritten, test.sh added.
- Tests: `./test.sh` → 24/24 checks passed. `swift build -c release` succeeded.
- Not done: live app launch/UI screenshot (not approved), installation/update end-to-end (not approved), Developer ID/notarization (needs credentials).

