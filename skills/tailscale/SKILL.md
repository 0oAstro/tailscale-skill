---
name: tailscale
description: Manage a Tailscale tailnet through the v2 REST API using deterministic curl+jq scripts with operationId-based invocation, dry-run previews, and explicit write confirmation. Use when Codex needs to list/read/update/delete Tailnet resources (devices, users, keys, DNS, services, policy file, logging, webhooks, invites, contacts) from scripts or terminal automation.
---

# Tailscale

## Overview
Use this skill to execute Tailscale API operations without ambiguity.
The scripts map `operationId -> method/path`, validate required path params/body, and enforce a safe write flow.

## Quick Start
1. Export auth:
```bash
export TS_API_KEY='tskey-api-...'
# optional override:
# export TS_API_BASE='https://api.tailscale.com/api/v2'
```
2. Discover operations:
```bash
./scripts/ts_catalog.sh --search device
./scripts/ts_catalog.sh --tag DNS --method GET
```
3. Preview request before execution:
```bash
./scripts/ts_call.sh listTailnetDevices \
  --params-json '{"tailnet":"acme.ts.net"}' \
  --dry-run
```
4. Execute and parse:
```bash
./scripts/ts_call.sh listTailnetDevices \
  --params-json '{"tailnet":"acme.ts.net"}' \
  --jq '.devices[] | {id,name,hostname,authorized}'
```

## Safe Mutation Workflow
For `POST/PUT/PATCH/DELETE`, `ts_call.sh` requires `--yes`.
Always run the same command with `--dry-run` first, verify URL/body, then rerun with `--yes`.

Example:
```bash
./scripts/ts_call.sh deleteDevice \
  --params-json '{"deviceId":"device-id"}' \
  --dry-run

./scripts/ts_call.sh deleteDevice \
  --params-json '{"deviceId":"device-id"}' \
  --yes
```

## Script Interfaces
### `scripts/ts_catalog.sh`
List/filter known operations from `references/operation_catalog.json`.

Arguments:
- `--tag <TAG>`
- `--method <GET|POST|PUT|PATCH|DELETE>`
- `--search <text>`
- `--json`

### `scripts/ts_call.sh`
Invoke one API operation by `operationId`.

Arguments:
- `<operationId>`
- `--params-json '<json object>'` for path params
- `--query-json '<json object>'` for query params
- `--body-json '<json object>'` or `--body-file <path>`
- `--jq '<filter>'` or `--raw`
- `--dry-run`
- `--yes` (required for mutating methods)

### `scripts/ts_build_catalog.sh`
Regenerate `references/operation_catalog.json` and `references/operations.tsv` from an OpenAPI spec.

Example:
```bash
./scripts/ts_build_catalog.sh /path/to/tailscale-api.json
```

## Canonical Usage Patterns
List devices:
```bash
./scripts/ts_call.sh listTailnetDevices \
  --params-json '{"tailnet":"acme.ts.net"}' \
  --jq '.devices[] | {id,nodeId,name,hostname,lastSeen,tags}'
```

Get one device:
```bash
./scripts/ts_call.sh getDevice \
  --params-json '{"deviceId":"device-id"}'
```

List keys:
```bash
./scripts/ts_call.sh listTailnetKeys \
  --params-json '{"tailnet":"acme.ts.net"}'
```

Create key:
```bash
./scripts/ts_call.sh createKey \
  --params-json '{"tailnet":"acme.ts.net"}' \
  --body-json '{"capabilities":{"devices":{"create":{"reusable":false,"ephemeral":false,"preauthorized":true,"tags":["tag:ci"]}}},"expirySeconds":3600}' \
  --dry-run

./scripts/ts_call.sh createKey \
  --params-json '{"tailnet":"acme.ts.net"}' \
  --body-json '{"capabilities":{"devices":{"create":{"reusable":false,"ephemeral":false,"preauthorized":true,"tags":["tag:ci"]}}},"expirySeconds":3600}' \
  --yes
```

Update ACL policy file:
```bash
./scripts/ts_call.sh setPolicyFile \
  --params-json '{"tailnet":"acme.ts.net"}' \
  --body-file ./acl.hujson \
  --dry-run

./scripts/ts_call.sh setPolicyFile \
  --params-json '{"tailnet":"acme.ts.net"}' \
  --body-file ./acl.hujson \
  --yes
```

Validate and test an ACL policy file before applying it:
```bash
./scripts/ts_call.sh validateAndTestPolicyFile \
  --params-json '{"tailnet":"acme.ts.net"}' \
  --body-file ./acl.hujson \
  --dry-run

./scripts/ts_call.sh validateAndTestPolicyFile \
  --params-json '{"tailnet":"acme.ts.net"}' \
  --body-file ./acl.hujson \
  --yes
```

## Practical Notes
### Staged tag rollouts
New tags cannot be assigned to devices until those tags already exist in the live policy's `tagOwners`.

Safe sequence:
1. Apply a bootstrap policy that introduces the new `tagOwners` but keeps existing connectivity semantics.
2. Retag devices with `setDeviceTags`.
3. Validate the final restrictive policy with `validateAndTestPolicyFile`.
4. Apply the final policy with `setPolicyFile`.

This avoids API errors like:
```text
requested tags [tag:server] are invalid or not permitted
```

### Validator quirks
- `validateAndTestPolicyFile` is treated as a mutating `POST` by `ts_call.sh`, so it requires `--yes`. Use `--dry-run` first to confirm the request shape.
- Prefer validating against the live tailnet after any tag changes, because policy `tests` and `sshTests` evaluate against current device tags.

### Policy syntax pitfalls
- `sshTests[].dst` must be an array, not a string.
- `sshTests[].dst` is stricter than `ssh[].dst`; host aliases like `"asuna"` and selectors like `"autogroup:self"` can fail in `sshTests` even if they are valid elsewhere. Tag-based destinations are more reliable in `sshTests`.
- `grants` destination matching is easy to misuse when mixing host aliases and tags. For host-specific network assertions, keep explicit `hosts` aliases for `tests`, but keep `grants` and `ssh` centered on tags where possible.
- If a validator error says `invalid dst ...`, reduce the rule to tag-based selectors first, then reintroduce host aliases only where confirmed to work.

### SSH relay caveat
Tailscale SSH authorizes the immediate source node, not the human identity that first logged into that source node.

Example:
- If Rahul can SSH to `rahul@debian`
- And `debian` is allowed to SSH to `shaurya@asuna`
- Then `rahul -> debian -> asuna` is viable from Tailscale's perspective

Changing the destination username alone does not prevent that second hop. To block it, remove the relay permission or isolate the relay onto a host Rahul cannot access.

## Resources
- `references/operation_catalog.json`: full operation catalog generated from OpenAPI (85 operations).
- `references/operations.tsv`: index/method/path/operationId table.
