#!/usr/bin/env bash
set -euo pipefail

transaction_hash="${PUBLISH_TX_HASH:?Set PUBLISH_TX_HASH}"
source_domain="${CIRCLE_SOURCE_DOMAIN:-0}"
api_base="${CIRCLE_ATTESTATION_API:-https://iris-api-sandbox.circle.com}"
transmitter="${UNICHAIN_CIRCLE_MESSAGE_TRANSMITTER:?Set UNICHAIN_CIRCLE_MESSAGE_TRANSMITTER}"
rpc_url="${ORIGIN_RPC_URL:?Set ORIGIN_RPC_URL}"
private_key="${PRIVATE_KEY:?Set PRIVATE_KEY}"
gas_limit="${CIRCLE_RELAY_GAS_LIMIT:-1200000}"
url="${api_base}/v2/messages/${source_domain}?transactionHash=${transaction_hash}"

chain_id="$(cast chain-id --rpc-url "$rpc_url")"
if [[ "$chain_id" != "1301" ]]; then
  printf 'Wrong relay network: expected Unichain Sepolia (1301), received %s.\n' "$chain_id" >&2
  exit 1
fi

if [[ ! "$transaction_hash" =~ ^0x[0-9a-fA-F]{64}$ ]]; then
  printf 'PUBLISH_TX_HASH must be a 32-byte transaction hash.\n' >&2
  exit 1
fi

response="$(curl --fail --silent --show-error "$url")"
message_status="$(jq -er '.messages[0].status' <<<"$response")"
if [[ "$message_status" != "complete" ]]; then
  printf 'Circle message status is %s. Retry shortly.\n' "$message_status" >&2
  exit 2
fi

destination="$(jq -er '.messages[0].decodedMessage.destinationDomain' <<<"$response")"
if [[ "$destination" != "10" ]]; then
  printf 'Unexpected Circle destination domain: expected 10, received %s.\n' "$destination" >&2
  exit 1
fi

version="$(jq -er '.messages[0].version' <<<"$response")"
if [[ "$version" != "2" ]]; then
  printf 'Unexpected Circle message version: expected 2, received %s.\n' "$version" >&2
  exit 1
fi

finality="$(jq -er '.messages[0].decodedMessage.finalityThresholdExecuted' <<<"$response")"
if (( finality < 1000 )); then
  printf 'Circle attestation finality is below the CCTP V2 confirmed threshold: %s.\n' "$finality" >&2
  exit 1
fi

message="$(jq -er '.messages[0].message' <<<"$response")"
attestation="$(jq -er '.messages[0].attestation' <<<"$response")"
if [[ ! "$message" =~ ^0x([0-9a-fA-F]{2})+$ ]] || [[ ! "$attestation" =~ ^0x([0-9a-fA-F]{2})+$ ]]; then
  printf 'Circle returned malformed message or attestation bytes.\n' >&2
  exit 1
fi
receipt="$(
  cast send "$transmitter" 'receiveMessage(bytes,bytes)(bool)' "$message" "$attestation" \
    --private-key "$private_key" \
    --gas-limit "$gas_limit" \
    --rpc-url "$rpc_url" \
    --json
)"

relay_hash="$(jq -er '.transactionHash' <<<"$receipt")"
relay_status="$(jq -er '.status' <<<"$receipt")"
if [[ "$relay_status" != "0x1" ]]; then
  printf 'Circle relay failed: %s\n' "$relay_hash" >&2
  exit 1
fi

printf 'Circle message relayed in transaction %s.\n' "$relay_hash"
