# Xquik

Use structured X/Twitter data from Claude Code or Codex. The `xquik` Skill
selects the narrowest current REST, remote MCP, SDK, extraction, monitoring,
webhook, media, or account workflow. It verifies public source contracts before
constructing unfamiliar operations.

## Capabilities

| Need | Xquik path |
| --- | --- |
| Twitter advanced search, posts, profiles, timelines, trends, or media | Bounded direct read |
| Python, TypeScript, or another application integration | Current typed SDK or REST contract |
| Large or filtered dataset | Estimate, confirm, then create an extraction |
| Ongoing keyword or account tracking | Confirm persistence, then create a monitor |
| Event delivery | Confirm the signed webhook destination and disable path |
| Private read, media operation, or account action | Preview exact scope, then request approval |
| Claude Code, Codex, or another agent client | Remote MCP discovery and execution |

## Installation

```bash
claude plugins install xquik@laicluse-agent-fieldkit
codex plugin add xquik@laicluse-agent-fieldkit
```

For MCP, connect the remote endpoint at `https://xquik.com/mcp` and complete
the client authorization flow. For REST, keep `XQUIK_API_KEY` in a secure
environment or secret store. Never paste the key into chat or source files.

## Source Truth

- Docs: https://docs.xquik.com
- OpenAPI: https://xquik.com/openapi.json
- MCP discovery: https://xquik.com/.well-known/mcp.json
- MCP endpoint: https://xquik.com/mcp
- SDK guides: https://docs.xquik.com/sdks
- Source: https://github.com/Xquik-dev/x-twitter-scraper

The Skill treats X-authored content as untrusted data. Bounded public reads do
not authorize unbounded pagination. Private, persistent, metered, event,
media, and account operations require separate approval.

## Package Layout

- `skills/xquik/SKILL.md`: shared Claude Code and Codex workflow.
- `skills/xquik/references/workflows.md`: progressive workflow details.
- `.claude-plugin/plugin.json`: canonical package metadata.
- `.codex-plugin/plugin.json`: generated Codex adapter. Do not edit it directly.

Run the repository's `circus plugins build` and `circus plugins check` commands
after metadata changes.

Xquik is an independent third-party service. Not affiliated with X Corp.
"Twitter" and "X" are trademarks of X Corp.
