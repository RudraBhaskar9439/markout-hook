#!/usr/bin/env bash

set -euo pipefail

origin_rpc="${ORIGIN_RPC_URL:-https://sepolia.unichain.org}"
reactive_rpc="${REACTIVE_RPC_URL:-https://lasna-omni-rpc.rnk.dev}"
usdc="0x31d0220469e10c4E71834a79b1f276d740d3768F"
weth="0x4200000000000000000000000000000000000006"

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
        printf '%s has no deployed code at %s\n' "$label" "$address" >&2
        exit 1
    fi
}

require_pool() {
    local pool="$1"
    local expected_fee="$2"
    local token0 token1 fee liquidity
    token0="$(cast call "$pool" 'token0()(address)' --rpc-url "$origin_rpc")"
    token1="$(cast call "$pool" 'token1()(address)' --rpc-url "$origin_rpc")"
    fee="$(cast call "$pool" 'fee()(uint24)' --rpc-url "$origin_rpc" | awk '{print $1}')"
    liquidity="$(cast call "$pool" 'liquidity()(uint128)' --rpc-url "$origin_rpc" | awk '{print $1}')"
    require_equal "$token0" "$usdc" "Reference pool token0"
    require_equal "$token1" "$weth" "Reference pool token1"
    require_equal "$fee" "$expected_fee" "Reference pool fee"
    if (( liquidity < 50000000000000 )); then
        printf 'Reference pool %s liquidity is below the configured floor\n' "$pool" >&2
        exit 1
    fi
}

require_equal "$(cast chain-id --rpc-url "$origin_rpc")" "1301" "Origin chain ID"
require_equal "$(cast chain-id --rpc-url "$reactive_rpc")" "5318007" "Reactive chain ID"

require_code "0x00b036b58a818b1bc34d502d3fe730db729e62ac" "$origin_rpc" "Uniswap v4 PoolManager"
require_code "0x9140a78c1a137c7ff1c151ec8231272af78a99a4" "$origin_rpc" "Uniswap v4 swap router"
require_code "0x5fa728c0a5cfd51bee4b060773f50554c0c8a7ab" "$origin_rpc" "Uniswap v4 liquidity router"
require_code "0x9299472A6399Fd1027ebF067571Eb3e3D7837FC4" "$origin_rpc" "Reactive callback proxy"
require_code "0x8888888888888888888888888888888888888888" "$reactive_rpc" "Reactive Lasna Omni system service"

require_pool "0xE87b0A6C6611119deCF5C4e9203E1c46F561BdAE" "100"
require_pool "0x8F463126bBEA80A10DF9Bf6FF5455B6B0292B34e" "3000"
require_pool "0xa88bF2bF5583b386B19E73D1a26A5Ab0Fa90f12D" "10000"

printf 'Phase 5 public-network preflight passed.\n'
