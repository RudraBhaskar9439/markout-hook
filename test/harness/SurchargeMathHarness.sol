// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { SurchargeMath } from "../../src/libraries/SurchargeMath.sol";

contract SurchargeMathHarness {
    function quoteBps(uint128 basisAmount, uint16 rateBps) external pure returns (uint128 amount) {
        return SurchargeMath.quoteBps(basisAmount, rateBps);
    }

    function toHookDelta(uint128 amount) external pure returns (int128 delta) {
        return SurchargeMath.toHookDelta(amount);
    }
}
