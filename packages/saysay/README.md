# saysay

Speech mode via the macOS `say` command. Once enabled, the agent speaks every
response aloud, translating screen content into spoken language instead of
reading it out verbatim.

## Commands

### `/saysay`

Enter speech mode. Subsequent responses are spoken aloud after rendering.

### `/saysay off`

Exit speech mode.

## Requirements

macOS. Speech mode needs the macOS `say` binary plus two scripts shipped with
the plugin (`saysay` and `say-phonetic`). Node.js on `$PATH` is needed for the
post-update broadcast check (`bin/check-broadcast`). The marketplace is
symlink-free to keep cross-platform consumers working, so put the scripts on
`PATH` with `cp -f`:

```bash
SRC=$(jq -r '.plugins["saysay@laicluse-agent-fieldkit"][0].installPath' ~/.claude/plugins/installed_plugins.json)
cp -f "$SRC/skills/saysay/saysay" /usr/local/bin/saysay
cp -f "$SRC/skills/saysay/say-phonetic" /usr/local/bin/say-phonetic
```

Re-run after each `claude plugins update saysay@laicluse-agent-fieldkit` so
the installed copies match the updated plugin.

Optional: a "Saysay Duck" / "Saysay Unduck" pair of macOS Shortcuts lets
saysay lower other audio while it speaks. When the shortcuts are absent,
saysay simply skips ducking.

## Phonetic mappings

`say-phonetic` keeps a per-user pronunciation dictionary so that names,
acronyms, and code identifiers come out the way you want. Mappings live in
`${LAICLUSE_HOME:-$HOME/.laicluse}/saysay/phonetics.json`. A dictionary left
over from an earlier `~/.local/share/saysay/phonetics.json` install is migrated
into the new root automatically on first use.

```bash
say-phonetic add "kbd" "keyboard"
say-phonetic remove "kbd"
say-phonetic list
```

## Installation

```bash
/plugin install saysay@laicluse-agent-fieldkit
```
