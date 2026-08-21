#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

manifest="${1:-deployments/hybrid-2026-08-21.json}"
source_rpc="${ETHEREUM_SEPOLIA_RPC_URL:?Set ETHEREUM_SEPOLIA_RPC_URL}"
destination_rpc="${ORIGIN_RPC_URL:?Set ORIGIN_RPC_URL to Unichain Sepolia}"

test "$(cast chain-id --rpc-url "$source_rpc")" = "11155111"
test "$(cast chain-id --rpc-url "$destination_rpc")" = "1301"

jq -e '
  .status == "circle-e2e-complete-reactive-pending"
  and .evidence.circleLive == true
  and .evidence.publicOutcomeCount == 3
  and .unichainSepolia.settlement.status == "settled"
  and .unichainSepolia.settlement.rebateClaimed == true
  and .unichainSepolia.adverseTrade.settlement.status == "settled"
  and .unichainSepolia.adverseTrade.settlement.retentionBps == 10000
  and .unichainSepolia.adverseTrade.settlement.rebate == "0"
  and .unichainSepolia.walletDemoTrade.settlement.status == "settled"
  and .unichainSepolia.walletDemoTrade.settlement.retentionBps == 0
  and .unichainSepolia.walletDemoTrade.settlement.rebateClaimed == true
' "$manifest" >/dev/null

verify_receipt() {
  local rpc_url="$1"
  local transaction_hash="$2"
  local label="$3"
  local receipt

  receipt="$(cast receipt "$transaction_hash" --rpc-url "$rpc_url" --json)"
  if ! jq -e '(.status == "0x1") or (.status == 1)' <<<"$receipt" >/dev/null; then
    printf '%s transaction failed or is unavailable: %s\n' "$label" "$transaction_hash" >&2
    exit 1
  fi
  printf 'Verified %s: %s\n' "$label" "$transaction_hash"
}

while IFS=$'\t' read -r label transaction_hash; do
  verify_receipt "$source_rpc" "$transaction_hash" "$label"
done < <(jq -r '
  ["publisher deployment", .ethereumSepolia.publisherDeploymentTx],
  ["publisher binding", .ethereumSepolia.publisherBindingTx],
  (.ethereumSepolia.observationPublishTxs[] | ["observation publication", .]),
  ["adverse observation publication", .ethereumSepolia.adverseObservationPublishTx],
  ["wallet-demo observation publication", .unichainSepolia.walletDemoTrade.observationPublishTx]
  | @tsv
' "$manifest")

while IFS=$'\t' read -r label transaction_hash; do
  verify_receipt "$destination_rpc" "$transaction_hash" "$label"
done < <(jq -r '
  (.unichainSepolia.destinationDeploymentTxs[] | ["destination deployment", .]),
  ["pool initialization", .unichainSepolia.poolInitializationTx],
  (.unichainSepolia.poolBootstrapTxs[] | ["pool bootstrap", .]),
  ["swap approval", .unichainSepolia.swapApprovalTx],
  ["MARKOUT swap", .unichainSepolia.swapTx],
  ["Circle settlement relay", .unichainSepolia.circleRelayTx],
  ["idempotent Circle relay", .unichainSepolia.duplicateCircleRelayTx],
  ["rebate claim", .unichainSepolia.rebateClaimTx],
  ["adverse swap approval", .unichainSepolia.adverseTrade.swapApprovalTx],
  ["adverse MARKOUT swap", .unichainSepolia.adverseTrade.swapTx],
  ["adverse Circle settlement relay", .unichainSepolia.adverseTrade.circleRelayTx],
  ["wallet-demo MARKOUT swap", .unichainSepolia.walletDemoTrade.swapTx],
  ["wallet-demo Circle settlement relay", .unichainSepolia.walletDemoTrade.circleRelayTx],
  ["wallet-demo rebate claim", .unichainSepolia.walletDemoTrade.rebateClaimTx]
  | @tsv
' "$manifest")

publisher="$(jq -er '.ethereumSepolia.publisher' "$manifest")"
coordinator="$(jq -er '.unichainSepolia.settlementCoordinator' "$manifest")"
circle_receiver="$(jq -er '.unichainSepolia.circleReceiver' "$manifest")"
hook="$(jq -er '.unichainSepolia.markoutHook' "$manifest")"
trade_id="$(jq -er '.unichainSepolia.tradeId' "$manifest")"
adverse_trade_id="$(jq -er '.unichainSepolia.adverseTrade.tradeId' "$manifest")"
wallet_demo_trade_id="$(jq -er '.unichainSepolia.walletDemoTrade.tradeId' "$manifest")"

for contract_address in "$publisher"; do
  test "$(cast code "$contract_address" --rpc-url "$source_rpc")" != "0x"
done
for contract_address in "$coordinator" "$circle_receiver" "$hook"; do
  test "$(cast code "$contract_address" --rpc-url "$destination_rpc")" != "0x"
done

trade_json="$(
  cast call "$hook" \
    'getTrade(bytes32)((bytes32,address,address,uint192,uint128,uint64,uint64,uint64,uint8,uint8))' \
    "$trade_id" \
    --rpc-url "$destination_rpc" \
    --json
)"
jq -e '.[0][9] == 2' <<<"$trade_json" >/dev/null

settlement_json="$(
  cast call "$hook" \
    'getTradeSettlement(bytes32)((int256,uint192,uint128,uint128,uint64,uint16,uint16))' \
    "$trade_id" \
    --rpc-url "$destination_rpc" \
    --json
)"
jq -e --arg markout "$(jq -er '.unichainSepolia.settlement.markoutWad' "$manifest")" \
  --arg rebate "$(jq -er '.unichainSepolia.settlement.rebate' "$manifest")" '
    (.[0][0] | tostring) == $markout
    and (.[0][3] | tostring) == $rebate
  ' <<<"$settlement_json" >/dev/null

beneficiary="$(jq -er '.[0][1]' <<<"$trade_json")"
currency="$(jq -er '.[0][2]' <<<"$trade_json")"
claimable="$(
  cast call "$hook" 'claimableRebate(address,address)(uint256)' "$beneficiary" "$currency" \
    --rpc-url "$destination_rpc" \
    --json
)"
jq -e '(.[0] | tonumber) == 0' <<<"$claimable" >/dev/null

adverse_trade_json="$(
  cast call "$hook" \
    'getTrade(bytes32)((bytes32,address,address,uint192,uint128,uint64,uint64,uint64,uint8,uint8))' \
    "$adverse_trade_id" \
    --rpc-url "$destination_rpc" \
    --json
)"
jq -e '.[0][9] == 2' <<<"$adverse_trade_json" >/dev/null

adverse_settlement_json="$(
  cast call "$hook" \
    'getTradeSettlement(bytes32)((int256,uint192,uint128,uint128,uint64,uint16,uint16))' \
    "$adverse_trade_id" \
    --rpc-url "$destination_rpc" \
    --json
)"
jq -e \
  --arg markout "$(jq -er '.unichainSepolia.adverseTrade.settlement.markoutWad' "$manifest")" \
  --arg retained "$(jq -er '.unichainSepolia.adverseTrade.settlement.retainedSurcharge' "$manifest")" '
    (.[0][0] | tostring) == $markout
    and (.[0][2] | tostring) == $retained
    and (.[0][3] | tonumber) == 0
    and .[0][6] == 10000
  ' <<<"$adverse_settlement_json" >/dev/null

adverse_pool_id="$(jq -er '.[0][0]' <<<"$adverse_trade_json")"
adverse_beneficiary="$(jq -er '.[0][1]' <<<"$adverse_trade_json")"
adverse_currency="$(jq -er '.[0][2]' <<<"$adverse_trade_json")"
adverse_retained="$(jq -er '.unichainSepolia.adverseTrade.settlement.retainedSurcharge' "$manifest")"

adverse_claimable="$(
  cast call "$hook" 'claimableRebate(address,address)(uint256)' "$adverse_beneficiary" "$adverse_currency" \
    --rpc-url "$destination_rpc" \
    --json
)"
jq -e '(.[0] | tonumber) == 0' <<<"$adverse_claimable" >/dev/null

for reserve_call in \
  "lpProtectionReserve(bytes32,address)(uint256) $adverse_pool_id $adverse_currency" \
  "totalLpProtectionReserve(address)(uint256) $adverse_currency" \
  "accountedBalance(address)(uint256) $adverse_currency" \
  "actualBalance(address)(uint256) $adverse_currency"; do
  # shellcheck disable=SC2086
  reserve_value="$(cast call "$hook" $reserve_call --rpc-url "$destination_rpc" --json)"
  jq -e --arg expected "$adverse_retained" '(.[0] | tostring) == $expected' <<<"$reserve_value" >/dev/null
done

wallet_demo_trade_json="$(
  cast call "$hook" \
    'getTrade(bytes32)((bytes32,address,address,uint192,uint128,uint64,uint64,uint64,uint8,uint8))' \
    "$wallet_demo_trade_id" \
    --rpc-url "$destination_rpc" \
    --json
)"
jq -e '.[0][9] == 2' <<<"$wallet_demo_trade_json" >/dev/null

wallet_demo_settlement_json="$(
  cast call "$hook" \
    'getTradeSettlement(bytes32)((int256,uint192,uint128,uint128,uint64,uint16,uint16))' \
    "$wallet_demo_trade_id" \
    --rpc-url "$destination_rpc" \
    --json
)"
jq -e \
  --arg markout "$(jq -er '.unichainSepolia.walletDemoTrade.settlement.markoutWad' "$manifest")" \
  --arg rebate "$(jq -er '.unichainSepolia.walletDemoTrade.settlement.rebate' "$manifest")" '
    (.[0][0] | tostring) == $markout
    and (.[0][2] | tonumber) == 0
    and (.[0][3] | tostring) == $rebate
    and .[0][6] == 0
  ' <<<"$wallet_demo_settlement_json" >/dev/null

wallet_demo_beneficiary="$(jq -er '.[0][1]' <<<"$wallet_demo_trade_json")"
wallet_demo_currency="$(jq -er '.[0][2]' <<<"$wallet_demo_trade_json")"
wallet_demo_claimable="$(
  cast call "$hook" 'claimableRebate(address,address)(uint256)' \
    "$wallet_demo_beneficiary" "$wallet_demo_currency" \
    --rpc-url "$destination_rpc" \
    --json
)"
jq -e '(.[0] | tonumber) == 0' <<<"$wallet_demo_claimable" >/dev/null

printf 'Public Circle evidence proves three complete lifecycles, both allocation extremes, and consistent accounting.\n'
