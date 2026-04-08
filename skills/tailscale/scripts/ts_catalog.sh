#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CATALOG="$SCRIPT_DIR/../references/operation_catalog.json"

if [[ ! -f "$CATALOG" ]]; then
  echo "error: catalog not found: $CATALOG" >&2
  exit 1
fi

TAG_FILTER=""
METHOD_FILTER=""
SEARCH_FILTER=""
JSON_MODE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tag)
      TAG_FILTER="${2:-}"
      shift 2
      ;;
    --method)
      METHOD_FILTER="${2:-}"
      shift 2
      ;;
    --search)
      SEARCH_FILTER="${2:-}"
      shift 2
      ;;
    --json)
      JSON_MODE=1
      shift
      ;;
    -h|--help)
      cat <<USAGE
Usage: ts_catalog.sh [--tag TAG] [--method METHOD] [--search TEXT] [--json]

Examples:
  ts_catalog.sh --tag Devices
  ts_catalog.sh --method GET --search device
  ts_catalog.sh --json
USAGE
      exit 0
      ;;
    *)
      echo "error: unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [[ "$JSON_MODE" -eq 1 ]]; then
  jq \
    --arg tag "$TAG_FILTER" \
    --arg method "$METHOD_FILTER" \
    --arg search "$SEARCH_FILTER" \
    '
      .
      | map(select(($tag == "") or (.tags | index($tag))))
      | map(select(($method == "") or (.method == ($method|ascii_upcase))))
      | map(select(($search == "") or ((.operationId + " " + .path + " " + .summary) | ascii_downcase | contains($search|ascii_downcase))))
    ' \
    "$CATALOG"
else
  {
    printf 'operationId\tverb\tpath\ttags\tsummary\n'
    jq -r \
      --arg tag "$TAG_FILTER" \
      --arg method "$METHOD_FILTER" \
      --arg search "$SEARCH_FILTER" \
      '
        .
        | map(select(($tag == "") or (.tags | index($tag))))
        | map(select(($method == "") or (.method == ($method|ascii_upcase))))
        | map(select(($search == "") or ((.operationId + " " + .path + " " + .summary) | ascii_downcase | contains($search|ascii_downcase))))
        | .[]
        | [.operationId, .method, .path, (.tags|join(",")), .summary]
        | @tsv
      ' \
      "$CATALOG"
  } | column -t -s $'\t'
fi
