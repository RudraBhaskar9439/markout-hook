#!/usr/bin/env bash
set -euo pipefail

price_id="${PYTH_PRICE_ID:?Set PYTH_PRICE_ID}"
api_key="${PYTH_API_KEY:?Set PYTH_API_KEY without committing it}"
endpoint="${PYTH_HERMES_URL:-https://hermes.pyth.network/v2/updates/price/latest}"

response="$(
  curl --fail --silent --show-error --get \
    --header "Authorization: Bearer ${api_key}" \
    --data-urlencode "ids[]=${price_id}" \
    --data-urlencode "encoding=hex" \
    --data-urlencode "parsed=true" \
    "$endpoint"
)"

update="$(jq -er '.binary.data[0]' <<<"$response")"
publish_time="$(jq -er '.parsed[0].price.publish_time' <<<"$response")"
price="$(jq -er '.parsed[0].price.price' <<<"$response")"
confidence="$(jq -er '.parsed[0].price.conf' <<<"$response")"

printf "export PYTH_UPDATE_DATA='0x%s'\n" "$update"
printf 'Pyth publish time: %s; raw price: %s; raw confidence: %s\n' "$publish_time" "$price" "$confidence" >&2
