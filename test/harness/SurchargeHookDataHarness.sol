// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { SurchargeHookData } from "../../src/libraries/SurchargeHookData.sol";
import { SurchargeAuthorization } from "../../src/types/SurchargeTypes.sol";

contract SurchargeHookDataHarness {
    function decode(bytes calldata data) external pure returns (address rebateRecipient, uint128 maximumAmount) {
        SurchargeAuthorization memory authorization = SurchargeHookData.decode(data);
        return (authorization.rebateRecipient, authorization.maximumAmount);
    }
}
