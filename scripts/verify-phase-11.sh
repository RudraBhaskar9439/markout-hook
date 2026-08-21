#!/usr/bin/env bash
set -euo pipefail

forge fmt --check
forge build --sizes
forge test --match-path 'test/hybrid/SettlementCoordinator.t.sol' -vv
forge test --match-test 'test_permissionlessExpiryReturnsFullEscrowAndBlocksSettlement' -vv
