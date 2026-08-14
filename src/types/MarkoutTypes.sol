// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @notice Direction of the trader's base-asset exposure.
enum TradeDirection {
    BuyBase,
    SellBase
}

/// @notice Orientation of a raw source price before canonical normalization.
enum PriceOrientation {
    QuotePerBase,
    BasePerQuote
}

/// @notice Piecewise-linear policy converting markout into retained-surcharge basis points.
/// @param favorableCutoffWad Absolute negative markout at which retention reaches its minimum.
/// @param adverseCutoffWad Positive markout at which the full surcharge is retained.
/// @param minimumRetentionBps Retention at or below the favorable cutoff.
/// @param neutralRetentionBps Retention at zero markout.
struct MarkoutCurve {
    uint64 favorableCutoffWad;
    uint64 adverseCutoffWad;
    uint16 minimumRetentionBps;
    uint16 neutralRetentionBps;
}

/// @notice Canonically normalized observation supplied by a reference-market adapter.
/// @param priceX18 Quote-token units per one base token, scaled by 1e18.
/// @param observedAt Timestamp assigned by the authenticated source adapter.
/// @param confidenceBps Normalized source confidence from 0 to 10,000, where higher is better.
struct ReferenceObservation {
    uint192 priceX18;
    uint64 observedAt;
    uint16 confidenceBps;
}

/// @notice Rules applied when selecting a reference observation for settlement.
/// @param maturityTimestamp Earliest acceptable observation timestamp.
/// @param evaluationTimestamp Timestamp at which validation is performed.
/// @param maximumAge Maximum age relative to evaluation time.
/// @param minimumConfidenceBps Minimum normalized source confidence.
/// @param settlementGracePeriod Maximum elapsed time after maturity during which settlement is allowed.
struct ObservationRules {
    uint64 maturityTimestamp;
    uint64 evaluationTimestamp;
    uint64 maximumAge;
    uint16 minimumConfidenceBps;
    uint64 settlementGracePeriod;
}

/// @notice Complete deterministic result of settling one provisional surcharge.
/// @param markoutWad Signed directional markout scaled by 1e18.
/// @param retentionBps Curve-selected retained share of the escrow.
/// @param retainedSurcharge Amount credited to LP protection.
/// @param rebate Amount credited back to the trader.
struct MarkoutSettlement {
    int256 markoutWad;
    uint16 retentionBps;
    uint128 retainedSurcharge;
    uint128 rebate;
}
