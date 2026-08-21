#!/usr/bin/env bash
set -euo pipefail

unichain_rpc="${ORIGIN_RPC_URL:-https://sepolia.unichain.org}"
sepolia_rpc="${ETHEREUM_SEPOLIA_RPC_URL:-${RPC_URL:-}}"
reactive_rpc="${REACTIVE_LEGACY_RPC_URL:-https://lasna-rpc.rnk.dev}"

if [[ -z "$sepolia_rpc" ]]; then
  printf 'Set ETHEREUM_SEPOLIA_RPC_URL to a reliable Ethereum Sepolia endpoint.\n' >&2
  exit 1
fi

pool_manager="${POOL_MANAGER:-0x00b036b58a818b1bc34d502d3fe730db729e62ac}"
callback_proxy="${REACTIVE_CALLBACK_PROXY:-0x9299472A6399Fd1027ebF067571Eb3e3D7837FC4}"
sepolia_circle="${SEPOLIA_CIRCLE_MESSAGE_TRANSMITTER:-0xE737e5cEBEEBa77EFE34D4aa090756590b1CE275}"
unichain_circle="${UNICHAIN_CIRCLE_MESSAGE_TRANSMITTER:-0xE737e5cEBEEBa77EFE34D4aa090756590b1CE275}"
pyth_contract="${PYTH_CONTRACT:-0xDd24F84d36BF92C65F92307595335bdFab5Bbd21}"
legacy_system="0x0000000000000000000000000000000000fffFfF"

require_equal() {
  local actual="$1"
  local expected="$2"
  local label="$3"
  local actual_lower expected_lower
  actual_lower="$(printf '%s' "$actual" | tr '[:upper:]' '[:lower:]')"
  expected_lower="$(printf '%s' "$expected" | tr '[:upper:]' '[:lower:]')"
  if [[ "$actual_lower" != "$expected_lower" ]]; then
    printf '%s mismatch: expected %s, received %s\n' "$label" "$expected" "$actual" >&2
    exit 1
  fi
}

require_code() {
  local address="$1"
  local rpc="$2"
  local label="$3"
  local code
  code="$(cast code "$address" --rpc-url "$rpc")"
  if [[ "$code" == "0x" ]]; then
    printf '%s has no deployed code at %s.\n' "$label" "$address" >&2
    exit 1
  fi
}

require_equal "$(cast chain-id --rpc-url "$unichain_rpc")" "1301" "Unichain chain ID"
require_equal "$(cast chain-id --rpc-url "$sepolia_rpc")" "11155111" "Ethereum Sepolia chain ID"
require_equal "$(cast chain-id --rpc-url "$reactive_rpc")" "5318007" "Reactive Lasna chain ID"

require_code "$pool_manager" "$unichain_rpc" "Uniswap v4 PoolManager"
require_code "$callback_proxy" "$unichain_rpc" "Reactive callback proxy"
require_code "$unichain_circle" "$unichain_rpc" "Unichain Circle MessageTransmitterV2"
require_code "$sepolia_circle" "$sepolia_rpc" "Sepolia Circle MessageTransmitterV2"
require_code "$pyth_contract" "$sepolia_rpc" "Sepolia Pyth contract"
require_code "$legacy_system" "$reactive_rpc" "Legacy Reactive system contract"

if [[ -n "${CIRCLE_PUBLISHER:-}" ]]; then
  require_code "$CIRCLE_PUBLISHER" "$sepolia_rpc" "Circle publisher"
  require_equal \
    "$(cast call "$CIRCLE_PUBLISHER" 'marketId()(bytes32)' --rpc-url "$sepolia_rpc")" \
    "${MARKET_ID:?Set MARKET_ID}" \
    "Circle publisher market"
fi

if [[ -n "${SETTLEMENT_COORDINATOR:-}" ]]; then
  require_code "$SETTLEMENT_COORDINATOR" "$unichain_rpc" "Settlement coordinator"
fi
if [[ -n "${CIRCLE_RECEIVER:-}" ]]; then
  require_code "$CIRCLE_RECEIVER" "$unichain_rpc" "Circle receiver"
  require_equal \
    "$(cast call "$CIRCLE_RECEIVER" 'sourcePublisher()(bytes32)' --rpc-url "$unichain_rpc")" \
    "$(cast to-bytes32 "$(cast to-uint256 "$CIRCLE_PUBLISHER")")" \
    "Circle receiver source publisher"
fi
if [[ -n "${REACTIVE_RECEIVER:-}" ]]; then
  require_code "$REACTIVE_RECEIVER" "$unichain_rpc" "Reactive receiver"
  require_equal \
    "$(cast call "$REACTIVE_RECEIVER" 'reactiveIdentity()(address)' --rpc-url "$unichain_rpc")" \
    "${REACTIVE_IDENTITY:?Set REACTIVE_IDENTITY}" \
    "Reactive receiver identity"
fi
if [[ -n "${MARKOUT_HOOK:-}" ]]; then
  require_code "$MARKOUT_HOOK" "$unichain_rpc" "MARKOUT hook"
  require_equal \
    "$(cast call "$MARKOUT_HOOK" 'settlementAuthority()(address)' --rpc-url "$unichain_rpc")" \
    "$SETTLEMENT_COORDINATOR" \
    "MARKOUT settlement authority"
fi
if [[ -n "${MARKOUT_PULSE:-}" ]]; then
  require_code "$MARKOUT_PULSE" "$reactive_rpc" "MARKOUT Reactive pulse"
  require_equal \
    "$(cast call "$MARKOUT_PULSE" 'sourcePublisher()(address)' --rpc-url "$reactive_rpc")" \
    "$CIRCLE_PUBLISHER" \
    "Reactive pulse publisher"
  require_equal \
    "$(cast call "$MARKOUT_PULSE" 'destinationReceiver()(address)' --rpc-url "$reactive_rpc")" \
    "$REACTIVE_RECEIVER" \
    "Reactive pulse receiver"
fi

printf 'Hybrid public-network preflight passed.\n'
