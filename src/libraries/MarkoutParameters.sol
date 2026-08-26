// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { MarkoutCurve, ObservationRules } from "../types/MarkoutTypes.sol";

/// @title MARKOUT MVP Parameters
/// @notice Versioned economic and observation defaults frozen for the UHI10 MVP.
library MarkoutParameters {
    uint256 internal constant WAD = 1e18;
    uint16 internal constant BPS_DENOMINATOR = 10_000;

    uint64 internal constant MATURITY_DELAY = 5 minutes;
    uint64 internal constant SETTLEMENT_GRACE_PERIOD = 10 minutes;
    uint64 internal constant MAXIMUM_SOURCE_PRICE_AGE = 2 minutes;
    // The publisher still validates a fresh Pyth update at source (120 seconds in the
    // testnet deployment). This destination bound additionally covers asynchronous
    // cross-chain delivery latency without extending the ten-minute settlement window.
    uint64 internal constant MAXIMUM_OBSERVATION_AGE = 5 minutes;
    uint16 internal constant MINIMUM_CONFIDENCE_BPS = 9000;

    // 5 bps and 25 bps expressed as signed-return WAD magnitudes.
    uint64 internal constant FAVORABLE_CUTOFF_WAD = 5e14;
    uint64 internal constant ADVERSE_CUTOFF_WAD = 25e14;
    uint16 internal constant MINIMUM_RETENTION_BPS = 0;
    uint16 internal constant NEUTRAL_RETENTION_BPS = 2000;

    error TimestampOverflow(uint64 timestamp, uint64 delay);

    /// @notice Returns the immutable Phase 2 retention curve.
    function defaultCurve() internal pure returns (MarkoutCurve memory curve) {
        curve = MarkoutCurve({
            favorableCutoffWad: FAVORABLE_CUTOFF_WAD,
            adverseCutoffWad: ADVERSE_CUTOFF_WAD,
            minimumRetentionBps: MINIMUM_RETENTION_BPS,
            neutralRetentionBps: NEUTRAL_RETENTION_BPS
        });
    }

    /// @notice Computes the MVP maturity timestamp without permitting uint64 wraparound.
    function maturityTimestamp(uint64 executedAt) internal pure returns (uint64 maturity) {
        if (executedAt > type(uint64).max - MATURITY_DELAY) {
            revert TimestampOverflow(executedAt, MATURITY_DELAY);
        }
        return executedAt + MATURITY_DELAY;
    }

    /// @notice Computes the final settlement deadline without permitting uint64 wraparound.
    function expiryTimestamp(uint64 maturity) internal pure returns (uint64 expiry) {
        if (maturity > type(uint64).max - SETTLEMENT_GRACE_PERIOD) {
            revert TimestampOverflow(maturity, SETTLEMENT_GRACE_PERIOD);
        }
        return maturity + SETTLEMENT_GRACE_PERIOD;
    }

    /// @notice Returns the Phase 2 default validation rules for a known maturity and evaluation time.
    function defaultObservationRules(uint64 maturity, uint64 evaluation)
        internal
        pure
        returns (ObservationRules memory rules)
    {
        rules = ObservationRules({
            maturityTimestamp: maturity,
            evaluationTimestamp: evaluation,
            maximumAge: MAXIMUM_OBSERVATION_AGE,
            minimumConfidenceBps: MINIMUM_CONFIDENCE_BPS,
            settlementGracePeriod: SETTLEMENT_GRACE_PERIOD
        });
    }
}
