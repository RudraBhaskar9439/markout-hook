// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { MarkoutParameters } from "../../src/libraries/MarkoutParameters.sol";
import { MarkoutCurve, ObservationRules } from "../../src/types/MarkoutTypes.sol";

contract MarkoutParametersHarness {
    function maturityTimestamp(uint64 executedAt) external pure returns (uint64) {
        return MarkoutParameters.maturityTimestamp(executedAt);
    }

    function settlementGracePeriod() external pure returns (uint64) {
        return MarkoutParameters.SETTLEMENT_GRACE_PERIOD;
    }

    function expiryTimestamp(uint64 maturity) external pure returns (uint64) {
        return MarkoutParameters.expiryTimestamp(maturity);
    }

    function defaultCurve() external pure returns (MarkoutCurve memory) {
        return MarkoutParameters.defaultCurve();
    }

    function defaultObservationRules(uint64 maturity, uint64 evaluation)
        external
        pure
        returns (ObservationRules memory)
    {
        return MarkoutParameters.defaultObservationRules(maturity, evaluation);
    }
}
