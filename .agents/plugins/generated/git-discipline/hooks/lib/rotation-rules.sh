#!/bin/bash
# Sourceable mnemonic-passwords for the commit-subject rotation reminders.
# Each ack must match the password tied to its rule number, e.g.
# `# ack-rule8:inferno`. The password is referential to the rule (vivid
# image you can hook the rule onto), so looking it up in the skill forces
# one exposure to the rule text per ack cycle. The skill at
# packages/git-discipline/skills/commit-discipline/SKILL.md (section "Rotation
# reminders") is the canonical reference; this file is its enforcement
# mirror.

# Indexed 0-based: DD_RULE_PASSWORD[N-1] is the password for rule N.
# Rule 3 is owned by commit-format and not in the rotation; its slot stays
# empty so the index math lines up with the rule number.
DD_RULE_PASSWORD=(
  "gedrag"      # 1: subject = new behavior, not a git action
  "effect"      # 2: WHAT the system does, not the WHY trigger
  ""            #  3: owned by commit-format, no rotation slot
  "essentie"    # 4: body only 2-4 sentences of why
  "dubbelop"    # 5: file listings duplicate what the diff shows
  "proza"       # 6: prose, no bullet dumps or meta-narrative
  "atoom"       # 7: atomic commits, no drift
  "inferno"     # 8: never commit broken code with "fix in next"
  "solist"      # 9: no Co-Authored-By from AI tooling
  "incognito"   # 10: no Generated-with-Claude-Code footer
  "loep"        # 11: review staged diff before commit
  "bewijsstuk"  # 12: commit check is evidence, not gut feel
  "kralen"      # 13: preserve history, no squash merge
  "voorwaarts"  # allow-comment: 14: amend forbidden after push, fine before
  "steiger"     # allow-comment: 15: no internal AI-tooling or process vocabulary in subject/body
)

# allow-comment: lockstep invariant, keep entries below in sync with column 3 of "Rotation reminders" in packages/git-discipline/skills/commit-discipline/SKILL.md; indexing mirrors DD_RULE_PASSWORD (Rule N at idx N-1, slot 2 empty because Rule 3 is owned by commit-format).
DD_RULE_ESSENCE=(
  "subject names new system behavior, not the git action you took"
  "subject names what the system does now, not the trigger ('Address feedback')"
  ""
  "body only when needed: 2-4 sentences of WHY"
  "no file/class inventory in the body; the diff already shows files"
  "prose, no bullet dumps or meta-narrative ('reviewer asked', 'tests failed')"
  "atomic commit: split unrelated changes; impl+test of one feature = one commit"
  "never commit broken code with 'fix in next commit'"
  "no Co-Authored-By from AI tooling unless asked"
  "no 'Generated with Claude Code' footer"
  "review the staged diff before commit; tool output is not evidence"
  "commit check is evidence you observed the real result, not a green build, gut feel, or a screenshot that merely exists; for visual work look at the on-screen render, an offscreen capture can differ from what ships"
  "preserve history; never squash merge"
  "amend forbidden on pushed commits (rewrites public history); fine on unpushed, including gate-mandated fixes"
  "no AI-tooling/process vocab in subject/body (skill names, phase terms, 'after the panel reviewed')"
)
