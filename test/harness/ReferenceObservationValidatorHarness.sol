// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { ReferenceObservationValidator } from "../../src/libraries/ReferenceObservationValidator.sol";
import { ObservationRules, ReferenceObservation } from "../../src/types/MarkoutTypes.sol";

contract ReferenceObservationValidatorHarness {
    function validate(ReferenceObservation memory observation, ObservationRules memory rules)
        external
        pure
        returns (uint192)
    {
        return ReferenceObservationValidator.validate(observation, rules);
    }

    function isExpired(uint64 maturityTimestamp, uint64 evaluationTimestamp, uint64 gracePeriod)
        external
        pure
        returns (bool)
    {
        return ReferenceObservationValidator.isExpired(maturityTimestamp, evaluationTimestamp, gracePeriod);
    }
}
