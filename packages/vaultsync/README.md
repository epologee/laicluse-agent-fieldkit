# vaultsync

vaultsync turns a Markdown vault or note repository into a local-first sync backend. It watches a whole Git checkout, debounces Git-visible changes into commits, runs an optional verifier, and keeps the current branch reconciled with its upstream when one exists. It is built for prose-heavy repositories such as Markdown vaults, local knowledge stores, and other free-form text collections where small edits should become durable without every application reinventing sync.

Remote sync is optional. A repository without a remote or upstream still gets the core behavior: debounced auto-commits plus verification. When an upstream is configured later, vaultsync starts fetching, rebasing, resolving conflicts through the configured LLM command, and pushing the current branch. It follows the branch already checked out and never creates branches or remotes.

## Installation

```bash
claude plugins install vaultsync@laicluse-agent-fieldkit
codex plugin add vaultsync@laicluse-agent-fieldkit
```

The plugin ships a `vaultsync` CLI. If the command is not on `PATH`, run the installed plugin's `bin/vaultsync` with Node.

## Capabilities

- Registers a Git checkout as a vaultsync target.
- Stores runtime state under `${LAICLUSE_HOME:-$HOME/.laicluse}/vaultsync`.
- Installs a user-level macOS LaunchAgent for the daemon loop.
- Debounces dirty Git state before committing.
- Generates substantive English commit messages through the configured LLM command, with deterministic git-discipline-safe trailers.
- Runs an optional verifier before a cycle is considered clean.
- Asks the configured LLM command to repair bounded verifier failures for included text files.
- Claims `dibs` during mutating cycles so another agent does not edit the same checkout concurrently.
- When an upstream exists, fetches, rebases, resolves conflicts through the LLM command, and pushes the current branch.
- When no upstream exists, skips remote operations and remains a local auto-commit vault.

## Commands

```bash
vaultsync install [path] --llm-command '<json command>' [--verify '<command>']
vaultsync status [path] [--json]
vaultsync now [path] [--json]
vaultsync pause [path] [--minutes <n> | --until <time>] [--reason <text>]
vaultsync resume [path]
vaultsync doctor [path] --llm-command '<json command>'
vaultsync daemon
```

`install` resolves the requested path to the nearest Git worktree root and records that whole checkout. The current branch is the sync branch. The branch's upstream is recorded when present; missing upstream is allowed and means local-only mode.

`pause` always has an automatic resume deadline. The default is 120 minutes. If a pause expires while another live `dibs` holder still owns the checkout, vaultsync extends the pause by 60 minutes and repeats that rule until the lock clears.

## LLM Command Contract

The configured LLM command reads one JSON object from stdin and writes one JSON object to stdout. The protocol field is `vaultsync.llm.v1`.

For commit messages:

```json
{ "message": "Substantive English commit message body" }
```

vaultsync keeps the LLM-generated subject and body but canonicalizes the required trailers:

```text
Tests: n/a (docs-only)
Slice: docs-only
Red-then-green: n/a (no executable behaviour changed)
Vaultsync-Reason: <cycle reason>
```

For conflicts:

```json
{ "resolved": "full file content without conflict markers" }
```

Remote/upstream content is authoritative. If local-only material cannot be merged cleanly, the resolver may preserve it in a sidecar file named like `name.conflict-extra-info.md`, but the original path must keep the remote truth intact.

For verifier failures:

```json
{ "repairs": [{ "path": "relative/path.md", "content": "full replacement content", "reason": "short reason" }] }
```

vaultsync only accepts repairs for files included in the request. Verifier-reported files are included first, followed by current sync paths as context, with fixed limits on repair rounds, file count, and file size.

## Verification

Run the package tests from the source checkout:

```bash
npm test --prefix packages/vaultsync
```

The tests cover local-only installs without upstream, remote-backed sync cycles, managed sync hooks that explicitly permit `--no-verify`, verifier failure recording, and verifier repair loops.
