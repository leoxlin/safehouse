---
name: brew-sync
description: >-
  Audit and reconcile a Homebrew Brewfile against the machine's actual brew
  state, then run routine Homebrew maintenance. Finds explicitly-installed
  formulae/casks/taps missing from the Brewfile, deprecated/disabled formulae,
  and outdated packages, then interactively decides what to add, remove, or
  keep. Use when the user asks to check, audit, clean up, or sync their
  Brewfile, or to do Homebrew maintenance (update/upgrade/cleanup).
---

# brew-sync

Keep the `Brewfile` and the installed Homebrew state in agreement. The heavy
read-only analysis is scripted; every mutating decision (what to uninstall,
untap, or add to the Brewfile) is confirmed with the user first.

## Workflow

### 1. Audit (scripted, read-only)

Run the audit and show the user the result:

```bash
.agents/skills/brew-sync/scripts/audit.sh [path/to/Brewfile]
```

It mutates nothing and reports five things:
- Explicitly-installed formulae missing from the Brewfile (dependencies excluded).
- Casks installed but missing from the Brewfile.
- Taps present but not referenced by the Brewfile — and, for each, what (if
  anything) is installed from it.
- Deprecated / disabled installed formulae.
- Outdated packages, plus `brew bundle check`.

### 2. Maintenance (scripted, no input needed)

If the user wants routine maintenance, run:

```bash
.agents/skills/brew-sync/scripts/maintain.sh
```

This does `brew update`, `brew upgrade`, `brew autoremove`, `brew cleanup`, and
prints `brew doctor`. It never uninstalls a named package or edits the Brewfile.

### 3. Decide (interactive — this is the point of the skill)

Walk the audit output with the user. Do **not** guess intent for these:

- **Missing-from-Brewfile formulae/casks:** for each, ask *track it* (add to
  Brewfile) or *discard it* (uninstall). Group the question; don't ask one at a
  time if several share an obvious answer.
- **Unreferenced taps:** if the audit says "nothing installed", offer to
  `brew untap` it. If something IS installed from it, treat that package like
  any other missing item (track via its full name, or uninstall + untap).
- **Deprecated / disabled formulae:** these should normally be removed from the
  Brewfile and uninstalled — confirm, and mention any suggested replacement
  (e.g. `tldr` → `tealdeer`/`tlrc`).

Prefer `AskUserQuestion` to collect these decisions in one pass.

### 4. Apply

- **Uninstall:** `brew uninstall <pkg> ...`
- **Untap:** `brew untap <org/name> ...`
- **Add to Brewfile:** insert `brew '<name>'` / `cask '<name>'` keeping the
  file's existing alphabetical order. Put cross-platform tools in the shared
  (unconditional) section; only put a package inside the `if OS.mac?` block if
  it is genuinely macOS-only. A tapped formula goes in by its full name
  (`brew 'org/name/formula'`); the tap comes along implicitly.
- After changes, re-run `brew bundle check --file=<Brewfile>` to confirm it
  passes, and re-run `audit.sh` to confirm nothing is left untracked.

## Gotchas (learned the hard way)

- **`brew list --full-name` silently omits tap-prefixed packages.** To find
  what a tap installed, walk its `.rb` files and test `brew list --versions`
  (audit.sh already does this). Don't trust a "nothing installed" answer from
  `brew list --full-name | grep`.
- **An empty Cellar directory** (e.g. `Cellar/<name>/` with no version subdir)
  makes `brew list --versions <name>` print the name with a blank version even
  though nothing is installed and there's no keg to uninstall. It must be
  removed manually — see the deletion rule below.
- **Untrusted taps block uninstall.** If `brew uninstall` refuses with "untrusted
  tap", run `brew trust <org/name>` first, then uninstall and untap.
- **`git-delta` installs the `delta` binary** and is tracked as `delta` in the
  Brewfile — audit.sh already treats them as the same thing.
- **Uninstalling can orphan dependencies** (and the auto-remove output may list
  surprising things like the `wireshark` *formula*, which is unrelated to a
  `wireshark-app` *cask*). Run `brew autoremove` after a round of uninstalls.

## Deletion rule (hard constraint)

**Never run `rm -rf` or other destructive filesystem deletions yourself.** When
cleanup needs one — orphaned config files Homebrew leaves behind, or a stale
empty Cellar directory — print the exact command and ask the user to run it
(e.g. via `! <command>`). Non-destructive brew operations (`uninstall`,
`untap`, `trust`, `autoremove`, `cleanup`) are fine to run directly.
