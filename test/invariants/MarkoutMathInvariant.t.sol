// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { StdInvariant } from "forge-std/StdInvariant.sol";
import { Test } from "forge-std/Test.sol";

import { MarkoutMathHandler } from "./handlers/MarkoutMathHandler.sol";

contract MarkoutMathInvariantTest is StdInvariant, Test {
    MarkoutMathHandler private handler;

    function setUp() public {
        handler = new MarkoutMathHandler();
        targetContract(address(handler));
    }

    function invariant_settlementIsAlwaysBounded() public view {
        assertFalse(handler.boundsViolated());
    }

    function invariant_rebateAndRetentionAlwaysConserveEscrow() public view {
        assertFalse(handler.conservationViolated());
    }

    function invariant_retentionRateNeverExceedsOneHundredPercent() public view {
        assertFalse(handler.retentionViolated());
    }
}
