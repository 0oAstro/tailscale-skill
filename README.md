# tailscale-skill

A Claude Code / Codex skill for managing Tailscale tailnets through the v2 REST API.

Provides deterministic `curl`+`jq` scripts with operationId-based invocation, dry-run previews, and explicit write confirmation — so AI agents make safe, auditable Tailscale API calls.

## Features

- **85 operations** from the Tailscale v2 API: devices, users, keys, DNS, ACL policy, webhooks, invites, contacts, logging
- **`ts_catalog.sh`** — search/filter operations by tag, method, or keyword
- **`ts_call.sh`** — invoke any operation by `operationId` with path/query/body params
- **Dry-run by default** for mutations — always preview before `--yes`
- **Bundled OpenAPI spec** + regenerable catalog via `ts_build_catalog.sh`

## Prerequisites

- `curl`
- `jq`
- A Tailscale API key: [admin console → Settings → Keys](https://login.tailscale.com/admin/settings/keys)

## Installation

```bash
# Install via Claude Code marketplace
/plugin marketplace add 0oAstro/tailscale-skill
/plugin install tailscale

# Or clone directly
git clone https://github.com/0oAstro/tailscale-skill
```

## Usage

```bash
export TS_API_KEY='tskey-api-...'

# Discover available operations
./skills/tailscale/scripts/ts_catalog.sh --search device
./skills/tailscale/scripts/ts_catalog.sh --tag DNS --method GET

# Preview a request (no API call made)
./skills/tailscale/scripts/ts_call.sh listTailnetDevices \
  --params-json '{"tailnet":"acme.ts.net"}' \
  --dry-run

# Execute and filter output with jq
./skills/tailscale/scripts/ts_call.sh listTailnetDevices \
  --params-json '{"tailnet":"acme.ts.net"}' \
  --jq '.devices[] | {id,name,hostname,authorized}'

# Mutate with explicit confirmation (always dry-run first)
./skills/tailscale/scripts/ts_call.sh deleteDevice \
  --params-json '{"deviceId":"device-id"}' \
  --dry-run

./skills/tailscale/scripts/ts_call.sh deleteDevice \
  --params-json '{"deviceId":"device-id"}' \
  --yes
```

## Regenerating the catalog

The bundled spec lives at `skills/tailscale/references/tailscale-api.json`. To regenerate after a Tailscale API update:

```bash
# Uses bundled spec by default
./skills/tailscale/scripts/ts_build_catalog.sh

# Or point at a new spec
./skills/tailscale/scripts/ts_build_catalog.sh /path/to/tailscale-api.json
```

This rewrites `references/operation_catalog.json` and `references/operations.tsv`.

## Smoke test

```bash
./skills/tailscale/scripts/ts_smoke.sh
# OK: tailscale scripts smoke checks passed
```

## Structure

```
.claude-plugin/
  plugin.json          # Machine metadata for skill runtime
  marketplace.json     # Registry manifest
skills/
  tailscale/
    SKILL.md           # Skill instructions (loaded by Claude Code / Codex)
    agents/
      openai.yaml      # Agent interface definition
    scripts/
      ts_common.sh     # Shared helpers (auth, http_call, urlencode)
      ts_call.sh       # Invoke any operationId
      ts_catalog.sh    # Search/filter operations
      ts_build_catalog.sh  # Regenerate catalog from OpenAPI spec
      ts_smoke.sh      # Offline smoke checks
    references/
      tailscale-api.json      # Bundled OpenAPI spec
      operation_catalog.json  # 85 operations extracted from OpenAPI
      operations.tsv          # Human-readable index
```

## License

MIT
