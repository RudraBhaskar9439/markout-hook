// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Script, console2 } from "forge-std/Script.sol";

import { IMarkoutHook } from "../src/interfaces/IMarkoutHook.sol";

/// @notice Pays transaction gas for a rebate claim while forcing payment to the configured beneficiary.
contract SponsorMarkoutRebateClaim is Script {
    error ZeroHook();
    error ZeroBeneficiary();

    function run() external returns (uint256 amount) {
        uint256 sponsorPrivateKey = vm.envUint("PRIVATE_KEY");
        IMarkoutHook hook = IMarkoutHook(vm.envAddress("MARKOUT_HOOK"));
        address beneficiary = vm.envAddress("CLAIM_BENEFICIARY");
        address currency = vm.envAddress("CLAIM_CURRENCY");
        if (address(hook) == address(0)) revert ZeroHook();
        if (beneficiary == address(0)) revert ZeroBeneficiary();

        vm.startBroadcast(sponsorPrivateKey);
        amount = hook.claimRebateFor(beneficiary, currency);
        vm.stopBroadcast();

        console2.log("Sponsored rebate", amount);
        console2.log("Rebate beneficiary", beneficiary);
        console2.log("Claim currency", currency);
    }
}
