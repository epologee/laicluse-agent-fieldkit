# clipboard changelog

Each entry corresponds to the `version` in `.claude-plugin/plugin.json`. The
post-update broadcast (see `bin/check-broadcast`) shows the section for the
currently-installed version exactly once per machine. Use
the `--force` flag on the helper to re-read at any time.

Categories:

- **Breaking**: user must adapt
- **Added**: new commands, new optional behavior
- **Changed**: non-breaking adjustments worth knowing about
- **Fixed**: silent unless the bug was user-visible

Patch-level fixes that change nothing the user can observe are intentionally
omitted; the broadcast budget is for things the user benefits from knowing.
The helper writes the sentinel only when stdout is non-empty, so a CHANGELOG
without a `## [vX.Y.Z]` section stays silent on every update.

## [v2.0.1]

### Breaking

- **clipboard now ships from the public laicluse-agent-tools marketplace.**
  It replaces `clipboard@leclause`; uninstall that copy if you still have it.
  The commands are unchanged: `/clipboard` and `/clipboard slack`.

### Changed

- **The skill resolves its helper via the plugin root instead of a jq lookup
  of `installed_plugins.json`.** The `bin/clipboard-paths.sh` shim is gone;
  the plugin root always points at the active install, so the stale-cache and
  uninstalled-plugin failure modes the shim defended against no longer exist.

## [v1.0.21]

- **Changed**: `/clipboard slack` produces rich text again. Bold pastes as bold, lists as bullets, inline code in monospace. If you saw literal `*bold*` characters after `/clipboard slack`, that stops now.
- **Added**: Anti-regression note in the SKILL so the next "make this more consistent" pass does not flip back to plain-text mrkdwn.
