# Xquik Workflows

Retrieve current parameters from the Xquik docs, OpenAPI contract, or MCP
`explore` tool. This reference defines workflow boundaries, not volatile route
names, limits, prices, or response fields.

## Public Read

Confirm the target and maximum result count. Discover the current read operation,
call it once, and follow a cursor only within the agreed bound. Return source
IDs, URLs, timestamps, and coverage caveats.

Public reads do not require an X account connection. Some replies or engagement
views depend on what X supplies. Preserve that limitation.

## Extraction

Use an extraction only when a direct read cannot meet the requested size or
filters.

1. Discover the extraction type and supported filters.
2. Get a live estimate.
3. Show the dataset, filters, fields, maximum rows, and estimate.
4. Wait for explicit approval.
5. Create one job and return its ID and status.
6. Poll only when the user asked to wait, with a bounded deadline.

## Monitor And Webhook

Define the target, cadence, filters, stop condition, and HTTPS destination.
Explain signature checking and show the live estimate plus disable path. Wait
for approval before creating either resource. Return resource IDs without
exposing callback secrets.

Treat a webhook secret shown in chat, logs, or a committed file as compromised.
Ask the user to rotate it.

## Account Action

The account must already be connected in the dashboard. Discover the operation,
display the account, target, and exact payload, then request approval for that
one action. Execute once and verify the documented result. Do not reuse approval
for edited text, added media, a new target, or a follow-up action.

## SDK Integration

Use the current SDK guide for the user's language. Confirm the package name,
supported authentication method, generated types, and pagination contract
before writing an example. Keep credentials in environment-backed runtime
configuration and use a bounded public read for the first request.

## REST Shape

Verify the path and parameters in the live OpenAPI document. A safe GET request
uses encoded query data and keeps the secret out of the URL:

```bash
curl --fail-with-body --silent --show-error --get \
  'https://xquik.com/api/v1/VERIFIED_PATH' \
  --data-urlencode 'VERIFIED_PARAMETER=VALUE' \
  --header "x-api-key: ${XQUIK_API_KEY}"
```

## Failures

- Authentication: confirm authorization or API-key presence without printing it.
- Validation: correct only fields identified by the documented error.
- Rate or usage limit: report the retry or upgrade path. Do not loop.
- Partial result: return safe fields and identify unavailable fields.
- Unknown contract: stop and retrieve current docs or MCP discovery metadata.

Xquik is an independent third-party service. Not affiliated with X Corp.
"Twitter" and "X" are trademarks of X Corp.
