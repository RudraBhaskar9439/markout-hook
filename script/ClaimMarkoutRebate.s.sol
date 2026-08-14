// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Script, console2 } from "forge-std/Script.sol";

import { IMarkoutHook } from "../src/interfaces/IMarkoutHook.sol";

/// @notice Claims the broadcaster's settled MARKOUT rebate to a configured recipient.
contract ClaimMarkoutRebate is Script {
    error ZeroHook();
    error ZeroRecipient();

    function run() external returns (uint256 amount) {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        IMarkoutHook hook = IMarkoutHook(vm.envAddress("MARKOUT_HOOK"));
        address payable recipient = payable(vm.envOr("CLAIM_RECIPIENT", vm.addr(privateKey)));
        address currency = vm.envAddress("CLAIM_CURRENCY");
        if (address(hook) == address(0)) revert ZeroHook();
        if (recipient == address(0)) revert ZeroRecipient();

        vm.startBroadcast(privateKey);
        amount = hook.claimRebate(currency, recipient);
        vm.stopBroadcast();

        console2.log("Claimed rebate", amount);
        console2.log("Claim recipient", recipient);
        console2.log("Claim currency", currency);
    }
}
