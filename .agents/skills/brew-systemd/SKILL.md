---
name: brew-systemd
description: >-
  Linux only. Turn any Homebrew-installed command into a systemd *user* unit (a
  long-running daemon, or a scheduled job via a timer) under
  ~/.config/systemd/user. Resolves the brew binary to an absolute path, sets a
  brew-aware PATH, then installs, reloads, and starts it. Use when the user wants
  to run a brew command as a background service, on a schedule, or "as a systemd
  service / on login / on a timer". Not applicable on macOS.
---

# brew-systemd

> Linux only — systemd user units don't exist on macOS. The generator refuses
> to run on any non-Linux host.

Wrap a Homebrew command in a systemd **user** unit (no root; lives in
`~/.config/systemd/user/`). The mechanical generation — resolving the binary's
absolute path, writing the unit, `daemon-reload`, `enable --now` — is scripted.
Decide *with the user* whether they want a long-running daemon or a scheduled
job before generating anything.

## Decide first (interactive)

Confirm these before running the generator:

1. **Daemon or scheduled job?**
   - *Daemon* — runs continuously, restarts on failure (e.g. `syncthing`,
     `kanata`, a language server). Default shape.
   - *Scheduled* — runs to completion on a cadence (e.g. `restic backup`,
     a cleanup script). Needs an `OnCalendar` schedule → use `--timer`.
2. **Unit name** — short, kebab/alnum (e.g. `syncthing`, `nightly-backup`).
3. **Exact command + args** — exactly as the user would type it in a shell.
4. **For scheduled jobs:** the schedule (`daily`, `hourly`, `*-*-* 03:00:00`,
   `Mon *-*-* 09:00:00`) and whether to catch up missed runs (`--persistent`).

Prefer `AskUserQuestion` to settle daemon-vs-timer and the schedule in one pass
if any of it is ambiguous.

## Generate

```bash
.agents/skills/brew-systemd/scripts/make-unit.sh --name NAME [opts] -- COMMAND [ARGS...]
```

Everything after `--` is the command. The first token is resolved to an
absolute path (brew prefix is searched first, since systemd units have no brew
on `PATH`).

- **Preview before writing:** add `--dry-run` to print the unit(s) to stdout
  without touching the filesystem. Show this to the user to confirm, then re-run
  without `--dry-run`.
- **Daemon:**
  ```bash
  scripts/make-unit.sh --name syncthing -- syncthing --no-browser
  ```
- **Scheduled (oneshot + timer):**
  ```bash
  scripts/make-unit.sh --name nightly-backup --timer "*-*-* 03:00:00" \
    --persistent -- restic backup /home/llin
  ```

Useful options: `--description TEXT`, `--working-dir DIR`, `--env KEY=VAL`
(repeatable), `--restart POLICY` (daemons; default `on-failure`),
`--no-enable` (write + reload only, don't start).

By default the script writes the unit, runs `systemctl --user daemon-reload`,
and `systemctl --user enable --now` the service (or the `.timer`).

## Verify

- Daemon: `systemctl --user status <name>.service`
- Timer: `systemctl --user list-timers <name>.timer`
- Logs: `journalctl --user -u <name>.service -e`

## Lingering (headless persistence)

User services stop at logout unless **lingering** is enabled. The script checks
this and prints a reminder if it's off. Enabling it needs root, so don't run it
silently — surface the command for the user:

```bash
sudo loginctl enable-linger $USER
```

## Removing a unit

```bash
systemctl --user disable --now <name>.service   # or .timer
rm ~/.config/systemd/user/<name>.service        # ask the user to run rm
systemctl --user daemon-reload
```

Per the repo rule, **don't run `rm` yourself** — print the exact `rm` command
and ask the user to run it (e.g. via `! <command>`).

## Gotchas

- **No `brew services` here.** This skill intentionally builds plain user units
  so they're inspectable and portable; it does not wrap `brew services`.
- **Absolute ExecStart is mandatory.** systemd ignores your shell's PATH; the
  script resolves the binary and also sets `Environment=PATH=` to brew's bin so
  the command can find sibling brew tools at runtime.
- **Shell features don't work in ExecStart.** Pipes, `&&`, globs, `$VARS`,
  redirects are *not* interpreted by systemd. If the command needs them, point
  ExecStart at a small wrapper script (`bash -c '...'` works but quote it
  carefully) and pass that as the command.
- **`--timer` services have no `[Install]`/`WantedBy`** — the timer pulls the
  service in. Enable the `.timer`, not the `.service`.
