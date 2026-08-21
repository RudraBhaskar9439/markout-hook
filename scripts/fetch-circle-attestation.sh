#!/usr/bin/env bash
set -euo pipefail

transaction_hash="${PUBLISH_TX_HASH:?Set PUBLISH_TX_HASH to the Ethereum Sepolia publication transaction}"
source_domain="${CIRCLE_SOURCE_DOMAIN:-0}"
api_base="${CIRCLE_ATTESTATION_API:-https://iris-api-sandbox.circle.com}"
url="${api_base}/v2/messages/${source_domain}?transactionHash=${transaction_hash}"
temporary_file="$(mktemp)"
trap 'rm -f "$temporary_file"' EXIT

status_code="$(curl --silent --show-error --output "$temporary_file" --write-out '%{http_code}' "$url")"
if [[ "$status_code" == "404" ]]; then
  printf 'Circle has not indexed or attested this transaction yet. Retry this command shortly.\n' >&2
  exit 2
fi
if [[ "$status_code" != "200" ]]; then
  printf 'Circle attestation API returned HTTP %s.\n' "$status_code" >&2
  jq . "$temporary_file" >&2 2>/dev/null || true
  exit 1
fi

message_status="$(jq -er '.messages[0].status' "$temporary_file")"
if [[ "$message_status" != "complete" ]]; then
  printf 'Circle message status is %s. Retry this command after confirmation.\n' "$message_status" >&2
  exit 2
fi

message="$(jq -er '.messages[0].message' "$temporary_file")"
attestation="$(jq -er '.messages[0].attestation' "$temporary_file")"
destination="$(jq -er '.messages[0].decodedMessage.destinationDomain' "$temporary_file")"
if [[ "$destination" != "10" ]]; then
  printf 'Unexpected Circle destination domain: expected 10, received %s.\n' "$destination" >&2
  exit 1
fi

printf "export CIRCLE_MESSAGE='%s'\n" "$message"
printf "export CIRCLE_ATTESTATION='%s'\n" "$attestation"
printf 'Circle attestation is complete for destination domain 10.\n' >&2
