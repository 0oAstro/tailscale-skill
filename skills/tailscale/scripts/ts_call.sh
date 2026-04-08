#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=ts_common.sh
source "$SCRIPT_DIR/ts_common.sh"
CATALOG="$SCRIPT_DIR/../references/operation_catalog.json"

if [[ ! -f "$CATALOG" ]]; then
  echo "error: catalog not found: $CATALOG" >&2
  exit 1
fi

usage() {
  cat <<USAGE
Usage:
  ts_call.sh <operationId> [flags]

Flags:
  --params-json JSON    JSON object for path params, e.g. '{"tailnet":"acme.ts.net"}'
  --query-json JSON     JSON object for query params
  --body-json JSON      Inline JSON request body
  --body-file FILE      JSON body file path
  --jq FILTER           jq filter to apply to response
  --raw                 print raw response (ignore --jq)
  --dry-run             print resolved request and exit
  --yes                 required for mutating methods (POST/PUT/PATCH/DELETE)
  -h, --help            show help

Examples:
  ts_call.sh listTailnetDevices --params-json '{"tailnet":"acme.ts.net"}' --jq '.devices[] | {id,name,hostname}'
  ts_call.sh getDevice --params-json '{"deviceId":"device-id"}'
  ts_call.sh listTailnetKeys --params-json '{"tailnet":"acme.ts.net"}' --query-json '{"all":true}'
USAGE
}

if [[ $# -lt 1 ]]; then
  usage
  exit 1
fi

OP_ID="$1"
shift

PARAMS_JSON='{}'
QUERY_JSON='{}'
BODY_JSON=''
BODY_FILE=''
JQ_FILTER=''
RAW=0
DRY_RUN=0
CONFIRM_WRITE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --params-json)
      PARAMS_JSON="${2:-}"
      shift 2
      ;;
    --query-json)
      QUERY_JSON="${2:-}"
      shift 2
      ;;
    --body-json)
      BODY_JSON="${2:-}"
      shift 2
      ;;
    --body-file)
      BODY_FILE="${2:-}"
      shift 2
      ;;
    --jq)
      JQ_FILTER="${2:-}"
      shift 2
      ;;
    --raw)
      RAW=1
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --yes)
      CONFIRM_WRITE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

require_cmd jq

# Validate JSON inputs early
jq -e 'type=="object"' <<<"$PARAMS_JSON" >/dev/null
jq -e 'type=="object"' <<<"$QUERY_JSON" >/dev/null

op_json="$(jq -c --arg op "$OP_ID" '.[] | select(.operationId == $op)' "$CATALOG")"
if [[ -z "$op_json" ]]; then
  echo "error: operationId not found: $OP_ID" >&2
  echo "hint: run $SCRIPT_DIR/ts_catalog.sh --search '$OP_ID'" >&2
  exit 1
fi

method="$(jq -r '.method' <<<"$op_json")"
path_tpl="$(jq -r '.path' <<<"$op_json")"
req_body="$(jq -r '.requestBodyRequired' <<<"$op_json")"

# Resolve path params
resolved_path="$path_tpl"
while IFS= read -r p; do
  [[ -z "$p" ]] && continue
  v="$(jq -r --arg k "$p" '.[$k] // empty' <<<"$PARAMS_JSON")"
  if [[ -z "$v" ]]; then
    echo "error: missing required path param '$p' for $OP_ID" >&2
    exit 1
  fi
  enc_v="$(urlencode "$v")"
  resolved_path="$(sed "s|{$p}|$enc_v|g" <<<"$resolved_path")"
done < <(jq -r '.pathParams[].name' <<<"$op_json")

while IFS= read -r q; do
  [[ -z "$q" ]] && continue
  qv="$(jq -r --arg k "$q" '.[$k] // empty' <<<"$QUERY_JSON")"
  if [[ -z "$qv" ]]; then
    echo "error: missing required query param '$q' for $OP_ID" >&2
    exit 1
  fi
done < <(jq -r '.queryParams[] | select(.required == true) | .name' <<<"$op_json")

if [[ "$req_body" == "true" && -z "$BODY_JSON" && -z "$BODY_FILE" ]]; then
  echo "error: request body required for $OP_ID (use --body-json or --body-file)" >&2
  exit 1
fi
if [[ -n "$BODY_JSON" && -n "$BODY_FILE" ]]; then
  echo "error: use either --body-json or --body-file, not both" >&2
  exit 1
fi

tmp_body=""
if [[ -n "$BODY_JSON" ]]; then
  tmp_body="$(mktemp)"
  jq -c . <<<"$BODY_JSON" > "$tmp_body"
  BODY_FILE="$tmp_body"
fi

trap '[[ -n "${tmp_body:-}" && -f "$tmp_body" ]] && rm -f "$tmp_body"' EXIT

qs="$(build_query_string "$QUERY_JSON")"
url="$TS_API_BASE$resolved_path"
if [[ -n "$qs" ]]; then
  url="$url?$qs"
fi

if [[ "$DRY_RUN" -eq 0 && "$method" != "GET" && "$CONFIRM_WRITE" -ne 1 ]]; then
  echo "error: $OP_ID uses $method and may mutate state; re-run with --yes after validating with --dry-run" >&2
  exit 1
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "method=$method"
  echo "url=$url"
  if [[ -n "$BODY_FILE" ]]; then
    echo "body_file=$BODY_FILE"
  else
    echo "body_file=<none>"
  fi
  exit 0
fi

resp="$(http_call "$method" "$url" "$BODY_FILE")"

if [[ "$RAW" -eq 1 ]]; then
  printf '%s\n' "$resp"
  exit 0
fi

if [[ -n "$JQ_FILTER" ]]; then
  jq -r "$JQ_FILTER" <<<"$resp"
else
  jq . <<<"$resp"
fi
