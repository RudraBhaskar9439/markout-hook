#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

manifest="${1:-deployments/fair-flow-2026-08-22.json}"
source_rpc="${ETHEREUM_SEPOLIA_RPC_URL:?Set ETHEREUM_SEPOLIA_RPC_URL}"
destination_rpc="${ORIGIN_RPC_URL:?Set ORIGIN_RPC_URL to Unichain Sepolia}"

test "$(cast chain-id --rpc-url "$source_rpc")" = "11155111"
test "$(cast chain-id --rpc-url "$destination_rpc")" = "1301"

jq -e '
  .profile == "fair-flow-18-plus-50"
  and .status == "circle-e2e-complete"
  and .economics.poolBaseFeeBps == 18
  and .economics.poolFeeRaw == 1800
  and .economics.provisionalSurchargeBps == 50
  and .unichainSepolia.verificationSwap.status == "settled-and-claimed"
  and .unichainSepolia.verificationSwap.settlement.retainedSurcharge == "0"
  and .unichainSepolia.verificationSwap.settlement.rebate == "622"
  and .unichainSepolia.verificationSwap.settlement.retentionBps == 0
  and .unichainSepolia.verificationSwap.settlement.effectiveFeeBps == 18
  and .verification.circleLifecycleComplete == true
  and .verification.sponsoredClaimEntrypointExecuted == true
  and .verification.finalClaimableRebate == "0"
  and .verification.finalPoolPendingSurcharge == "0"
  and .verification.finalHookTokenBalance == "0"
' "$manifest" >/dev/null

verify_receipt() {
  local rpc_url="$1"
  local transaction_hash="$2"
  local label="$3"
  local receipt

  receipt="$(cast receipt "$transaction_hash" --rpc-url "$rpc_url" --json)"
  jq -e '(.status == "0x1") or (.status == 1)' <<<"$receipt" >/dev/null
  printf 'Verified %s: %s\n' "$label" "$transaction_hash"
}

while IFS=$'\t' read -r label transaction_hash; do
  verify_receipt "$source_rpc" "$transaction_hash" "$label"
done < <(jq -r '
  ["publisher deployment", .ethereumSepolia.publisherDeploymentTx],
  ["publisher binding", .ethereumSepolia.publisherBindingTx],
  ["observation publication", .ethereumSepolia.observationPublishTx]
  | @tsv
' "$manifest")

while IFS=$'\t' read -r label transaction_hash; do
  verify_receipt "$destination_rpc" "$transaction_hash" "$label"
done < <(jq -r '
  (.unichainSepolia.destinationDeploymentTxs[] | ["destination deployment", .]),
  ["pool initialization", .unichainSepolia.poolInitializationTx],
  (.unichainSepolia.poolBootstrapTxs[] | ["pool bootstrap", .]),
  ["swap approval", .unichainSepolia.verificationSwap.approvalTx],
  ["Fair-Flow swap", .unichainSepolia.verificationSwap.swapTx],
  ["Circle settlement", .unichainSepolia.verificationSwap.circleRelayTx],
  ["sponsored claim entrypoint", .unichainSepolia.verificationSwap.sponsoredClaimEntrypointTx]
  | @tsv
' "$manifest")

publisher="$(jq -er '.ethereumSepolia.publisher' "$manifest")"
coordinator="$(jq -er '.unichainSepolia.settlementCoordinator' "$manifest")"
circle_receiver="$(jq -er '.unichainSepolia.circleReceiver' "$manifest")"
reactive_receiver="$(jq -er '.unichainSepolia.reactiveReceiver' "$manifest")"
hook="$(jq -er '.unichainSepolia.markoutHook' "$manifest")"
pool_id="$(jq -er '.unichainSepolia.poolId' "$manifest")"
trade_id="$(jq -er '.unichainSepolia.verificationSwap.tradeId' "$manifest")"

test "$(cast code "$publisher" --rpc-url "$source_rpc")" != "0x"
for contract_address in "$coordinator" "$circle_receiver" "$reactive_receiver" "$hook"; do
  test "$(cast code "$contract_address" --rpc-url "$destination_rpc")" != "0x"
done

test "$(cast call "$publisher" 'destinationReceiver()(address)' --rpc-url "$source_rpc")" = "$circle_receiver"
test "$(cast call "$circle_receiver" 'sourcePublisher()(address)' --rpc-url "$destination_rpc")" = "$publisher"
test "$(cast call "$circle_receiver" 'settlementCoordinator()(address)' --rpc-url "$destination_rpc")" = "$coordinator"
test "$(cast call "$coordinator" 'target()(address)' --rpc-url "$destination_rpc")" = "$hook"
test "$(cast call "$hook" 'settlementAuthority()(address)' --rpc-url "$destination_rpc")" = "$coordinator"
test "$(cast call "$hook" 'surchargeBps()(uint16)' --rpc-url "$destination_rpc")" = "50"

trade_json="$(
  cast call "$hook" \
    'getTrade(bytes32)((bytes32,address,address,uint192,uint128,uint64,uint64,uint64,uint8,uint8))' \
    "$trade_id" --rpc-url "$destination_rpc" --json
)"
jq -e --arg pool_id "$pool_id" '
  .[0][0] == $pool_id
  and (.[0][4] | tostring) == "622"
  and .[0][9] == 2
' <<<"$trade_json" >/dev/null

settlement_json="$(
  cast call "$hook" \
    'getTradeSettlement(bytes32)((int256,uint192,uint128,uint128,uint64,uint16,uint16))' \
    "$trade_id" --rpc-url "$destination_rpc" --json
)"
jq -e \
  --arg markout "$(jq -er '.unichainSepolia.verificationSwap.settlement.markoutWad' "$manifest")" '
    (.[0][0] | tostring) == $markout
    and (.[0][2] | tonumber) == 0
    and (.[0][3] | tonumber) == 622
    and .[0][6] == 0
  ' <<<"$settlement_json" >/dev/null

beneficiary="$(jq -er '.[0][1]' <<<"$trade_json")"
currency="$(jq -er '.[0][2]' <<<"$trade_json")"
claimable="$(cast call "$hook" 'claimableRebate(address,address)(uint256)' "$beneficiary" "$currency" --rpc-url "$destination_rpc")"
pending="$(cast call "$hook" 'poolPendingSurcharge(bytes32,address)(uint256)' "$pool_id" "$currency" --rpc-url "$destination_rpc")"
reserve="$(cast call "$hook" 'lpProtectionReserve(bytes32,address)(uint256)' "$pool_id" "$currency" --rpc-url "$destination_rpc")"
actual="$(cast call "$currency" 'balanceOf(address)(uint256)' "$hook" --rpc-url "$destination_rpc")"
test "$claimable" = "0"
test "$pending" = "0"
test "$reserve" = "0"
test "$actual" = "0"

pool_manager="0x00b036b58a818b1bc34d502d3fe730db729e62ac"
pool_manager_lower="$(printf '%s' "$pool_manager" | tr '[:upper:]' '[:lower:]')"
pool_id_lower="$(printf '%s' "$pool_id" | tr '[:upper:]' '[:lower:]')"
pool_initialization_tx="$(jq -er '.unichainSepolia.poolInitializationTx' "$manifest")"
initialization_receipt="$(cast receipt "$pool_initialization_tx" --rpc-url "$destination_rpc" --json)"
initialization_data="$(
  jq -er --arg manager "$pool_manager_lower" --arg pool_id "$pool_id_lower" '
    .logs[]
    | select((.address | ascii_downcase) == $manager)
    | select((.topics[1] | ascii_downcase) == $pool_id)
    | .data
  ' <<<"$initialization_receipt"
)"
fee_word="0x${initialization_data:2:64}"
test "$(cast to-dec "$fee_word")" = "1800"

printf 'Fair-Flow public evidence proves an 18 bps pool, complete Circle settlement, rebate claim, and zero residual liabilities.\n'
