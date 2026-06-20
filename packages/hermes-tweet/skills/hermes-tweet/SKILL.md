---
name: hermes-tweet
user-invocable: true
description: >-
  Use Hermes Tweet for Hermes Agent X/Twitter search, social listening, and gated posting workflows.
---

# Hermes Tweet

Use Hermes Tweet when a Hermes Agent workflow needs X/Twitter search, account
reads, social listening, launch monitoring, creator research, support triage,
giveaway audits, or explicitly approved account actions.

Hermes Tweet source: <https://github.com/Xquik-dev/hermes-tweet>

## Install

Install and enable the upstream Hermes Agent plugin:

```bash
hermes plugins install Xquik-dev/hermes-tweet --enable
```

If Hermes discovers the plugin but does not enable it, run:

```bash
hermes plugins enable hermes-tweet
```

Set `XQUIK_API_KEY` in the Hermes runtime environment or `~/.hermes/.env`.
Never paste the key into chat, issue text, PR comments, logs, or tool
arguments.

## Tool Choice

- Use `tweet_explore` first to find a catalog-listed endpoint.
- Use `tweet_read` for public read-only `GET` endpoints after discovery.
- Use `tweet_action` only for private reads or account-changing actions after
  the user approves the exact endpoint and payload.

`tweet_action` is intentionally gated by `HERMES_TWEET_ENABLE_ACTIONS=true`.
Keep it disabled for unattended, scheduled, gateway, or monitoring workflows
unless that workflow has a clear approval step.

## Safety

- Do not guess endpoint paths.
- Do not pass credentials through tool arguments.
- Do not use account connection, re-authentication, billing, credit, API-key, or
  support-ticket endpoints.
- For posting, deleting, following, DMs, profile changes, monitors, webhooks,
  extraction jobs, or draws, summarize the action before calling `tweet_action`.
- For Hermes Desktop remote gateway profiles, install and configure Hermes
  Tweet on the remote Hermes runtime host where plugin tools execute.

## Quick Checks

```bash
hermes plugins list
hermes tools list
```

Confirm that `hermes-tweet` is enabled, `tweet_explore` is available, and action
tools remain hidden unless action gating is explicitly enabled.
