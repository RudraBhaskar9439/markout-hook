// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { BaseHook } from "@openzeppelin/uniswap-hooks/src/base/BaseHook.sol";

import { IPoolManager } from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import { Hooks } from "@uniswap/v4-core/src/libraries/Hooks.sol";
import { BalanceDelta } from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import { Currency } from "@uniswap/v4-core/src/types/Currency.sol";
import { PoolId, PoolIdLibrary } from "@uniswap/v4-core/src/types/PoolId.sol";
import { PoolKey } from "@uniswap/v4-core/src/types/PoolKey.sol";
import { SwapParams } from "@uniswap/v4-core/src/types/PoolOperation.sol";

import { IProvisionalSurchargeHook } from "../interfaces/IProvisionalSurchargeHook.sol";
import { SurchargeHookData } from "../libraries/SurchargeHookData.sol";
import { SurchargeMath } from "../libraries/SurchargeMath.sol";
import { SwapDeltaAccounting } from "../libraries/SwapDeltaAccounting.sol";
import { SurchargeAuthorization, SurchargeQuote, UnspecifiedSwapDelta } from "../types/SurchargeTypes.sol";

/// @title Base Provisional Surcharge Hook
/// @notice Reusable Uniswap v4 accounting primitive that escrows a policy-defined swap surcharge.
/// @dev The surcharge is collected in the swap's unspecified currency using `afterSwapReturnDelta`:
///      output for exact-input swaps, input for exact-output swaps. Implementations provide only the
///      pricing policy by overriding `_quoteSurcharge`.
abstract contract BaseProvisionalSurcharge is BaseHook, IProvisionalSurchargeHook {
    using PoolIdLibrary for PoolKey;

    mapping(bytes32 poolId => mapping(address currency => uint256 amount)) private _poolAccrued;
    mapping(address currency => uint256 amount) private _totalAccrued;

    constructor(IPoolManager poolManager_) BaseHook(poolManager_) { }

    /// @inheritdoc IProvisionalSurchargeHook
    function poolAccruedSurcharge(bytes32 poolId, address currency) external view returns (uint256 amount) {
        amount = _poolAccrued[poolId][currency];
    }

    /// @inheritdoc IProvisionalSurchargeHook
    function totalAccruedSurcharge(address currency) external view returns (uint256 amount) {
        amount = _totalAccrued[currency];
    }

    /// @inheritdoc BaseHook
    function getHookPermissions() public pure virtual override returns (Hooks.Permissions memory permissions) {
        permissions.afterSwap = true;
        permissions.afterSwapReturnDelta = true;
    }

    /// @dev Collects and records the provisional surcharge after the pool has produced its raw swap delta.
    function _afterSwap(
        address sender,
        PoolKey calldata key,
        SwapParams calldata params,
        BalanceDelta swapDelta,
        bytes calldata hookData
    ) internal virtual override returns (bytes4, int128 hookDelta) {
        SurchargeAuthorization memory authorization = SurchargeHookData.decode(hookData);
        UnspecifiedSwapDelta memory unspecified = SwapDeltaAccounting.unspecified(key, params, swapDelta);
        PoolId poolId = key.toId();

        SurchargeQuote memory quote = SurchargeQuote({
            poolId: poolId,
            swapSender: sender,
            rebateRecipient: authorization.rebateRecipient,
            currency: unspecified.currency,
            basisAmount: unspecified.amount,
            maximumAmount: authorization.maximumAmount,
            exactInput: params.amountSpecified < 0,
            zeroForOne: params.zeroForOne
        });

        uint128 surchargeAmount = _quoteSurcharge(quote);
        if (surchargeAmount > authorization.maximumAmount) {
            revert SurchargeExceedsMaximum(surchargeAmount, authorization.maximumAmount);
        }

        hookDelta = SurchargeMath.toHookDelta(surchargeAmount);
        if (surchargeAmount == 0) return (BaseHook.afterSwap.selector, hookDelta);

        address currencyAddress = Currency.unwrap(unspecified.currency);
        bytes32 rawPoolId = PoolId.unwrap(poolId);

        // `take` creates a transient debt for the hook. The positive return delta below offsets that
        // debt when PoolManager accounts the hook delta after this callback.
        poolManager.take(unspecified.currency, address(this), surchargeAmount);

        _poolAccrued[rawPoolId][currencyAddress] += surchargeAmount;
        _totalAccrued[currencyAddress] += surchargeAmount;

        _afterSurchargeAccrued(quote, surchargeAmount);

        emit ProvisionalSurchargeAccrued(
            rawPoolId,
            sender,
            authorization.rebateRecipient,
            currencyAddress,
            unspecified.amount,
            surchargeAmount,
            authorization.maximumAmount
        );

        return (BaseHook.afterSwap.selector, hookDelta);
    }

    /// @notice Returns the provisional surcharge for a resolved swap context.
    /// @dev Implementations must return a value no larger than `type(int128).max`.
    function _quoteSurcharge(SurchargeQuote memory quote) internal view virtual returns (uint128 amount);

    /// @notice Extension point invoked after custody and accounting have been updated.
    /// @dev Phase 3 will use this to create a pending MARKOUT settlement record.
    function _afterSurchargeAccrued(SurchargeQuote memory quote, uint128 amount) internal virtual { }

    /// @notice Accepts native currency transferred by `PoolManager.take` for native-token pools.
    receive() external payable virtual {
        if (msg.sender != address(poolManager)) revert NotPoolManager();
    }
}
