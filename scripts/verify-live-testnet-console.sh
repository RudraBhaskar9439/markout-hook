#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
rpc_url="${ORIGIN_RPC_URL:-https://sepolia.unichain.org}"
simulation_account="${TESTNET_SIMULATION_ACCOUNT:-0xd1DcAAFf9356d5a42f2eE6F90179C4509386a83f}"
hook="0x2981693161ebbeaf10e91d6ddfc2ed810e80c044"
router="0x9140a78c1a137c7ff1c151ec8231272af78a99a4"
usdc="0x31d0220469e10c4E71834a79b1f276d740d3768F"
weth="0x4200000000000000000000000000000000000006"
circle_transmitter="0xE737e5cEBEEBa77EFE34D4aa090756590b1CE275"
hook_data="0x000000000000000000000000${simulation_account#0x}00000000000000000000000000000000ffffffffffffffffffffffffffffffff"

for command_name in cast curl jq npm; do
  command -v "$command_name" >/dev/null || {
    printf 'Missing required command: %s\n' "$command_name" >&2
    exit 1
  }
done

chain_id="$(cast chain-id --rpc-url "$rpc_url")"
if [[ "$chain_id" != "1301" ]]; then
  printf 'Expected Unichain Sepolia chain 1301, received %s.\n' "$chain_id" >&2
  exit 1
fi

for contract_address in "$hook" "$router" "$usdc" "$weth" "$circle_transmitter"; do
  contract_code="$(cast code "$contract_address" --rpc-url "$rpc_url")"
  if [[ "$contract_code" == "0x" ]]; then
    printf 'No contract code at %s.\n' "$contract_address" >&2
    exit 1
  fi
done

surcharge_bps="$(cast call "$hook" 'surchargeBps()(uint16)' --rpc-url "$rpc_url" | awk '{print $1}')"
if [[ "$surcharge_bps" != "50" ]]; then
  printf 'Expected the deployed provisional surcharge to be 50 bps, received %s.\n' "$surcharge_bps" >&2
  exit 1
fi

cast call "$router" \
  'swap((address,address,uint24,int24,address),(bool,int256,uint160),(bool,bool),bytes)(int256)' \
  "($usdc,$weth,3000,60,$hook)" \
  '(true,-1000000,4295128740)' \
  '(false,false)' \
  "$hook_data" \
  --from "$simulation_account" \
  --rpc-url "$rpc_url" \
  >/dev/null

hermes_response="$(
  curl --fail --silent --show-error --get \
    --data-urlencode 'ids[]=0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace' \
    --data-urlencode 'encoding=hex' \
    --data-urlencode 'parsed=true' \
    'https://hermes.pyth.network/v2/updates/price/latest'
)"
jq -e '.binary.data[0] and .parsed[0].price.publish_time' <<<"$hermes_response" >/dev/null

cd "$repo_root/web"
npm run verify

printf 'Live testnet console verification passed: deployed contracts, read-only swap simulation, Pyth, and frontend are healthy.\n'
