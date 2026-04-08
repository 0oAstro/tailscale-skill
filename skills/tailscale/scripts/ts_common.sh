#!/usr/bin/env bash
set -euo pipefail

# Shared helpers for Tailscale API calls.

TS_API_BASE="${TS_API_BASE:-https://api.tailscale.com/api/v2}"
TS_API_KEY="${TS_API_KEY:-${TAILSCALE_API_KEY:-}}"

require_cmd() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "error: required command missing: $cmd" >&2
    exit 1
  }
}

require_env() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "error: missing env var $name" >&2
    exit 1
  fi
}

urlencode() {
  local raw="$1"
  jq -nr --arg v "$raw" '$v|@uri'
}

build_query_string() {
  local query_json="$1"
  jq -r '
    if (type != "object") then
      error("query JSON must be an object")
    else
      to_entries
      | map(select(.value != null))
      | map("\(.key|@uri)=\((.value|tostring)|@uri)")
      | join("&")
    end
  ' <<<"$query_json"
}

http_call() {
  local method="$1"
  local url="$2"
  local body_file="${3:-}"
  local content_type="${4:-application/json}"

  require_cmd curl
  require_env TS_API_KEY

  local -a curl_args
  curl_args=(
    -sS
    -X "$method"
    -H "Authorization: Bearer $TS_API_KEY"
    -H "Accept: application/json"
    "$url"
  )

  if [[ -n "$body_file" ]]; then
    curl_args+=(
      -H "Content-Type: $content_type"
      --data-binary "@$body_file"
    )
  fi

  curl "${curl_args[@]}"
}
