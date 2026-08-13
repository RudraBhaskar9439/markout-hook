// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IPoolManager } from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";

import { BaseProvisionalSurcharge } from "../base/BaseProvisionalSurcharge.sol";
import { IProvisionalSurchargeHook } from "../interfaces/IProvisionalSurchargeHook.sol";
import { SurchargeMath } from "../libraries/SurchargeMath.sol";
import { SurchargeQuote } from "../types/SurchargeTypes.sol";

/// @title Fixed-BPS Provisional Surcharge Hook
/// @notice Production-shaped Phase 1 policy used to prove MARKOUT's escrow accounting.
contract FixedBpsProvisionalSurchargeHook is BaseProvisionalSurcharge {
    /// @notice Constructor cap protecting integrations from accidentally deploying punitive rates.
    uint16 public constant MAX_SURCHARGE_BPS = 1000;

    /// @notice Provisional surcharge rate applied to the unspecified swap amount.
    uint16 public immutable surchargeBps;

    constructor(IPoolManager poolManager_, uint16 surchargeBps_) BaseProvisionalSurcharge(poolManager_) {
        if (surchargeBps_ > MAX_SURCHARGE_BPS) {
            revert IProvisionalSurchargeHook.SurchargeRateTooHigh(surchargeBps_, MAX_SURCHARGE_BPS);
        }
        surchargeBps = surchargeBps_;
    }

    /// @inheritdoc BaseProvisionalSurcharge
    function _quoteSurcharge(SurchargeQuote memory quote) internal view override returns (uint128 amount) {
        amount = SurchargeMath.quoteBps(quote.basisAmount, surchargeBps);
    }
}
