# tailscale-skill

AI agent skill for managing a Tailscale tailnet through the v2 REST API. No SDKs, no libraries — just `curl` and `jq` scripts that your agent can call by name.

Every operation has a dry-run mode. Mutations require explicit confirmation. You see exactly what `curl` command would run before it runs.

## What you get

- **85 API operations** — devices, users, keys, DNS, ACL policy, webhooks, invites, contacts, logging
- **`ts_catalog.sh`** — list and filter operations by tag, method, or text search
- **`ts_call.sh`** — call any operation by its `operationId`, pass path/query/body params, pipe through `jq`
- **Dry-run by default** for any POST/PUT/PATCH/DELETE. You preview the curl command, verify it, then pass `--yes` to execute.
- **Full OpenAPI spec bundled** — regenerate the catalog when Tailscale adds endpoints

You need `curl` and `jq`. That's it.

## Setup

```bash
# Grab an API key from your Tailscale admin console
# https://login.tailscale.com/admin/settings/keys
export TS_API_KEY='tskey-api-...'

# If you use Claude Code:
/plugin marketplace add 0oAstro/tailscale-skill
/plugin install tailscale

# Or just clone it
git clone https://github.com/0oAstro/tailscale-skill
```

## Usage

```bash
# Find the operation you need
./skills/tailscale/scripts/ts_catalog.sh --search device
./skills/tailscale/scripts/ts_catalog.sh --tag DNS --method GET

# Preview before touching anything
./skills/tailscale/scripts/ts_call.sh listTailnetDevices \
  --params-json '{"tailnet":"acme.ts.net"}' \
  --dry-run

# Execute and filter with jq
./skills/tailscale/scripts/ts_call.sh listTailnetDevices \
  --params-json '{"tailnet":"acme.ts.net"}' \
  --jq '.devices[] | {id,name,hostname,authorized}'

# Mutations require --yes. Always dry-run first.
./skills/tailscale/scripts/ts_call.sh deleteDevice \
  --params-json '{"deviceId":"device-id"}' \
  --dry-run

./skills/tailscale/scripts/ts_call.sh deleteDevice \
  --params-json '{"deviceId":"device-id"}' \
  --yes
```

## Regenerating the catalog

The bundled OpenAPI spec is at `skills/tailscale/references/tailscale-api.json`. When Tailscale adds new endpoints:

```bash
# Uses the bundled spec
./skills/tailscale/scripts/ts_build_catalog.sh

# Or point at an updated spec
./skills/tailscale/scripts/ts_build_catalog.sh /path/to/tailscale-api.json
```

This rewrites `references/operation_catalog.json` and `references/operations.tsv`.

## Smoke test

```bash
./skills/tailscale/scripts/ts_smoke.sh
# OK: tailscale scripts smoke checks passed
```

## Project structure

```
.claude-plugin/
  plugin.json          # Plugin manifest
  marketplace.json     # Marketplace metadata
skills/
  tailscale/
    SKILL.md           # Loaded by Claude Code / Codex
    agents/
      openai.yaml      # Agent interface definition
    scripts/
      ts_common.sh     # Shared helpers (auth, http_call, urlencode)
      ts_call.sh       # Invoke any operationId
      ts_catalog.sh    # Search/filter operations
      ts_build_catalog.sh  # Regenerate from OpenAPI spec
      ts_smoke.sh      # Offline smoke check
    references/
      tailscale-api.json          # Full OpenAPI spec
      operation_catalog.json      # 85 extracted operations
      operations.tsv              # Human-readable index
```

## License

MIT
