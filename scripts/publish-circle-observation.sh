#!/usr/bin/env bash
set -euo pipefail

publisher="${CIRCLE_PUBLISHER:?Set CIRCLE_PUBLISHER}"
trade_id="${TRADE_ID:?Set TRADE_ID}"
pyth_contract="${PYTH_CONTRACT:?Set PYTH_CONTRACT}"
price_id="${PYTH_PRICE_ID:?Set PYTH_PRICE_ID}"
hermes_url="${PYTH_HERMES_URL:?Set PYTH_HERMES_URL}"
rpc_url="${ETHEREUM_SEPOLIA_RPC_URL:?Set ETHEREUM_SEPOLIA_RPC_URL}"
private_key="${PRIVATE_KEY:?Set PRIVATE_KEY}"
gas_limit="${CIRCLE_PUBLISH_GAS_LIMIT:-500000}"

chain_id="$(cast chain-id --rpc-url "$rpc_url")"
if [[ "$chain_id" != "11155111" ]]; then
  printf 'Wrong publication network: expected Ethereum Sepolia (11155111), received %s.\n' "$chain_id" >&2
  exit 1
fi

headers=()
if [[ -n "${PYTH_API_KEY:-}" ]]; then
  headers+=(--header "Authorization: Bearer ${PYTH_API_KEY}")
fi

response="$({
  curl --fail --silent --show-error --get \
    "${headers[@]}" \
    --data-urlencode "ids[]=${price_id}" \
    --data-urlencode "encoding=hex" \
    --data-urlencode "parsed=true" \
    "$hermes_url"
})"

update_data="0x$(jq -er '.binary.data[0]' <<<"$response")"
publish_time="$(jq -er '.parsed[0].price.publish_time' <<<"$response")"
if [[ ! "$update_data" =~ ^0x([0-9a-fA-F]{2})+$ ]]; then
  printf 'Hermes returned malformed Pyth update data.\n' >&2
  exit 1
fi
update_fee="$(
  cast call "$pyth_contract" 'getUpdateFee(bytes[])(uint256)' "[$update_data]" --rpc-url "$rpc_url"
)"

receipt="$(
  cast send "$publisher" 'publish(bytes32,bytes[])' "$trade_id" "[$update_data]" \
    --value "$update_fee" \
    --private-key "$private_key" \
    --gas-limit "$gas_limit" \
    --rpc-url "$rpc_url" \
    --json
)"

transaction_hash="$(jq -er '.transactionHash' <<<"$receipt")"
transaction_status="$(jq -er '.status' <<<"$receipt")"
if [[ "$transaction_status" != "0x1" ]]; then
  printf 'Circle observation publication failed: %s\n' "$transaction_hash" >&2
  exit 1
fi

printf "export PUBLISH_TX_HASH='%s'\n" "$transaction_hash"
printf 'Published Pyth observation %s in transaction %s.\n' "$publish_time" "$transaction_hash" >&2
