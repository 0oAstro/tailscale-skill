# tailscale-skill

Manage a Tailscale tailnet from your AI coding agent. 85 API operations, deterministic bash scripts, no server to run.

Works with Claude Code, Codex, Gemini CLI, Cursor, OpenCode — anything that can run a bash script and read a markdown file.

## Install

```bash
# Claude Code
/plugin marketplace add 0oAstro/tailscale-skill
/plugin install tailscale

# Everyone else
git clone https://github.com/0oAstro/tailscale-skill
cd tailscale-skill
export TS_API_KEY='tskey-api-...'
```

You need `curl` and `jq`. That's it.

## Usage

**Find what you need:**
```bash
./skills/tailscale/scripts/ts_catalog.sh --search device
./skills/tailscale/scripts/ts_catalog.sh --tag DNS --method GET
```

**Preview before touching anything:**
```bash
./skills/tailscale/scripts/ts_call.sh listTailnetDevices \
  --params-json '{"tailnet":"acme.ts.net"}' \
  --dry-run
```

**Execute and pipe through jq:**
```bash
./skills/tailscale/scripts/ts_call.sh listTailnetDevices \
  --params-json '{"tailnet":"acme.ts.net"}' \
  --jq '.devices[] | {id,name,hostname,authorized}'
```

**Mutations require --yes. Always dry-run first.**
```bash
./skills/tailscale/scripts/ts_call.sh deleteDevice \
  --params-json '{"deviceId":"device-id"}' \
  --dry-run

# Looks right? Then:
./skills/tailscale/scripts/ts_call.sh deleteDevice \
  --params-json '{"deviceId":"device-id"}' \
  --yes
```

## What you get

| Script | Purpose |
|--------|---------|
| `ts_catalog.sh` | List and filter operations by tag, method, or text |
| `ts_call.sh` | Call any operation by operationId with path/query/body params |
| `ts_build_catalog.sh` | Regenerate the catalog from an updated OpenAPI spec |
| `ts_smoke.sh` | Offline smoke test |

Covers: **devices, users, keys, DNS, ACL policy, webhooks, invites, contacts, logging** — 85 endpoints total.

Each call returns raw JSON. Pipe through `--jq` to shape the output.

## Common commands

```bash
# List devices
ts_call.sh listTailnetDevices --params-json '{"tailnet":"acme.ts.net"}' --jq '.devices[]'

# Get one device
ts_call.sh getDevice --params-json '{"deviceId":"device-id"}'

# List keys
ts_call.sh listTailnetKeys --params-json '{"tailnet":"acme.ts.net"}'

# Create a key (dry-run first)
ts_call.sh createKey --params-json '{"tailnet":"acme.ts.net"}' \
  --body-json '{"capabilities":{"devices":{"create":{"reusable":false,"ephemeral":false,"preauthorized":true,"tags":["tag:ci"]}}},"expirySeconds":3600}' \
  --dry-run

# Update ACL
ts_call.sh setPolicyFile --params-json '{"tailnet":"acme.ts.net"}' --body-file ./acl.hujson --dry-run

# Validate ACL before applying
ts_call.sh validateAndTestPolicyFile --params-json '{"tailnet":"acme.ts.net"}' --body-file ./acl.hujson --dry-run
```

## Regenerating the catalog

The bundled OpenAPI spec lives at `skills/tailscale/references/tailscale-api.json`. When Tailscale adds endpoints:

```bash
./skills/tailscale/scripts/ts_build_catalog.sh
# or point at a new spec:
./skills/tailscale/scripts/ts_build_catalog.sh /path/to/tailscale-api.json
```

## Stuff to watch out for

**Tag rollouts need a bootstrap step.** You can't assign tags unless they already exist in the live policy's `tagOwners`. Apply a bootstrap policy first, retag, then apply the final restrictive policy.

**validateAndTestPolicyFile counts as a mutation.** It's a POST, so it needs --yes. Use --dry-run first.

**Policy tests evaluate against live device state.** If you changed device tags since the last policy apply, validate after the tag change, not before.

**sshTests[].dst is picky.** These must be arrays, not strings. They're stricter than ssh[].dst. Things like `"asuna"` or `"autogroup:self"` can fail in sshTests even if they work in ssh rules. Use tag-based destinations here.

**grants + host aliases = footgun.** For tests use explicit hosts aliases. For grants and ssh rules, stick to tags. If a validator says `invalid dst ...`, strip down to tag selectors first, then reintroduce host aliases one at a time.

**SSH relay works differently than you expect.** Tailscale SSH authorizes the immediate source node, not the human who logged into it. If Rahul can SSH to debian, and debian can SSH to asuna, then Rahul can reach asuna through debian. Changing the username doesn't block this. Remove the relay permission or lock down the intermediate host.

## Structure

```
skills/tailscale/
  SKILL.md                      # Instructions loaded by the agent
  agents/openai.yaml            # Agent interface definition
  scripts/
    ts_common.sh                # Shared helpers
    ts_call.sh                  # Invoke any operationId
    ts_catalog.sh               # Search and filter operations
    ts_build_catalog.sh         # Regenerate from OpenAPI spec
    ts_smoke.sh                 # Offline smoke check
  references/
    tailscale-api.json           # Full OpenAPI spec
    operation_catalog.json       # 85 extracted operations
    operations.tsv               # Human-readable index
```

## License

MIT
