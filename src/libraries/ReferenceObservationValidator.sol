// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { ObservationRules, ReferenceObservation } from "../types/MarkoutTypes.sol";
import { MarkoutParameters } from "./MarkoutParameters.sol";

/// @title Reference Observation Validator
/// @notice Applies deterministic maturity, freshness, and normalized-confidence rules.
library ReferenceObservationValidator {
    error MissingObservation();
    error ZeroObservationPrice();
    error MaturityNotReached(uint64 maturityTimestamp, uint64 evaluationTimestamp);
    error SettlementWindowExpired(uint64 elapsedAfterMaturity, uint64 settlementGracePeriod);
    error ObservationBeforeMaturity(uint64 observedAt, uint64 maturityTimestamp);
    error ObservationFromFuture(uint64 observedAt, uint64 evaluationTimestamp);
    error StaleObservation(uint64 age, uint64 maximumAge);
    error InvalidConfidence(uint16 confidenceBps);
    error ConfidenceBelowMinimum(uint16 confidenceBps, uint16 minimumConfidenceBps);
    error InvalidMinimumConfidence(uint16 minimumConfidenceBps);

    /// @notice Reverts unless an observation is eligible for markout settlement.
    function validate(ReferenceObservation memory observation, ObservationRules memory rules)
        internal
        pure
        returns (uint192 priceX18)
    {
        if (rules.minimumConfidenceBps > MarkoutParameters.BPS_DENOMINATOR) {
            revert InvalidMinimumConfidence(rules.minimumConfidenceBps);
        }
        if (rules.evaluationTimestamp < rules.maturityTimestamp) {
            revert MaturityNotReached(rules.maturityTimestamp, rules.evaluationTimestamp);
        }
        uint64 elapsedAfterMaturity = rules.evaluationTimestamp - rules.maturityTimestamp;
        if (elapsedAfterMaturity > rules.settlementGracePeriod) {
            revert SettlementWindowExpired(elapsedAfterMaturity, rules.settlementGracePeriod);
        }
        if (observation.observedAt == 0) revert MissingObservation();
        if (observation.priceX18 == 0) revert ZeroObservationPrice();
        if (observation.confidenceBps > MarkoutParameters.BPS_DENOMINATOR) {
            revert InvalidConfidence(observation.confidenceBps);
        }
        if (observation.observedAt < rules.maturityTimestamp) {
            revert ObservationBeforeMaturity(observation.observedAt, rules.maturityTimestamp);
        }
        if (observation.observedAt > rules.evaluationTimestamp) {
            revert ObservationFromFuture(observation.observedAt, rules.evaluationTimestamp);
        }

        uint64 age = rules.evaluationTimestamp - observation.observedAt;
        if (age > rules.maximumAge) revert StaleObservation(age, rules.maximumAge);
        if (observation.confidenceBps < rules.minimumConfidenceBps) {
            revert ConfidenceBelowMinimum(observation.confidenceBps, rules.minimumConfidenceBps);
        }

        return observation.priceX18;
    }

    /// @notice Returns true only after the complete settlement grace period has elapsed.
    /// @dev Subtraction avoids overflow from `maturityTimestamp + gracePeriod`.
    function isExpired(uint64 maturityTimestamp, uint64 evaluationTimestamp, uint64 gracePeriod)
        internal
        pure
        returns (bool)
    {
        if (evaluationTimestamp <= maturityTimestamp) return false;
        return evaluationTimestamp - maturityTimestamp > gracePeriod;
    }
}
