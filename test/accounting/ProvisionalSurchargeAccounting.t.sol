// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Test } from "forge-std/Test.sol";
import { Vm } from "forge-std/Vm.sol";

import { BaseHook } from "@openzeppelin/uniswap-hooks/src/base/BaseHook.sol";

import { IHooks } from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import { IPoolManager } from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import { CustomRevert } from "@uniswap/v4-core/src/libraries/CustomRevert.sol";
import { Hooks } from "@uniswap/v4-core/src/libraries/Hooks.sol";
import { TransientStateLibrary } from "@uniswap/v4-core/src/libraries/TransientStateLibrary.sol";
import { PoolSwapTest } from "@uniswap/v4-core/src/test/PoolSwapTest.sol";
import { BalanceDelta, toBalanceDelta } from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import { Currency, CurrencyLibrary } from "@uniswap/v4-core/src/types/Currency.sol";
import { PoolId, PoolIdLibrary } from "@uniswap/v4-core/src/types/PoolId.sol";
import { PoolKey } from "@uniswap/v4-core/src/types/PoolKey.sol";
import { SwapParams } from "@uniswap/v4-core/src/types/PoolOperation.sol";
import { Deployers } from "@uniswap/v4-core/test/utils/Deployers.sol";

import { FixedBpsProvisionalSurchargeHook } from "../../src/hooks/FixedBpsProvisionalSurchargeHook.sol";
import { IProvisionalSurchargeHook } from "../../src/interfaces/IProvisionalSurchargeHook.sol";
import { SurchargeHookData } from "../../src/libraries/SurchargeHookData.sol";
import { SurchargeMath } from "../../src/libraries/SurchargeMath.sol";
import { SurchargeAuthorization } from "../../src/types/SurchargeTypes.sol";

contract ProvisionalSurchargeAccountingTest is Test, Deployers {
    using CurrencyLibrary for Currency;
    using PoolIdLibrary for PoolKey;
    using TransientStateLibrary for IPoolManager;

    uint16 private constant SURCHARGE_BPS = 50;
    address private constant REBATE_RECIPIENT = address(0xBEEF);
    bytes32 private constant ACCRUAL_EVENT_SIGNATURE =
        keccak256("ProvisionalSurchargeAccrued(bytes32,address,address,address,uint128,uint128,uint128)");

    struct AccrualEvent {
        bytes32 poolId;
        address swapSender;
        address rebateRecipient;
        address currency;
        uint128 basisAmount;
        uint128 surchargeAmount;
        uint128 maximumAmount;
    }

    struct ParticipantBalances {
        uint256 user;
        uint256 manager;
        uint256 hook;
        uint256 router;
    }

    FixedBpsProvisionalSurchargeHook private hook;
    PoolKey private surchargePoolKey;
    PoolId private surchargePoolId;

    function setUp() public {
        deployFreshManagerAndRouters();
        deployMintAndApprove2Currencies();

        address hookAddress = _hookAddress(0x4D41);
        deployCodeTo(
            "src/hooks/FixedBpsProvisionalSurchargeHook.sol:FixedBpsProvisionalSurchargeHook",
            abi.encode(manager, SURCHARGE_BPS),
            hookAddress
        );
        hook = FixedBpsProvisionalSurchargeHook(payable(hookAddress));

        (surchargePoolKey, surchargePoolId) =
            initPoolAndAddLiquidity(currency0, currency1, IHooks(hookAddress), 3000, SQRT_PRICE_1_1);

        vm.label(hookAddress, "FixedBpsProvisionalSurchargeHook");
        vm.label(REBATE_RECIPIENT, "RebateRecipient");
    }

    function test_permissions_areMinimalAndCorrect() public view {
        Hooks.Permissions memory permissions = hook.getHookPermissions();

        assertTrue(permissions.afterSwap);
        assertTrue(permissions.afterSwapReturnDelta);
        assertFalse(permissions.beforeInitialize);
        assertFalse(permissions.afterInitialize);
        assertFalse(permissions.beforeAddLiquidity);
        assertFalse(permissions.afterAddLiquidity);
        assertFalse(permissions.beforeRemoveLiquidity);
        assertFalse(permissions.afterRemoveLiquidity);
        assertFalse(permissions.beforeSwap);
        assertFalse(permissions.beforeDonate);
        assertFalse(permissions.afterDonate);
        assertFalse(permissions.beforeSwapReturnDelta);
        assertFalse(permissions.afterAddLiquidityReturnDelta);
        assertFalse(permissions.afterRemoveLiquidityReturnDelta);
    }

    function test_afterSwap_directCall_reverts() public {
        SwapParams memory params = _swapParams(true, true, 1 ether);

        vm.expectRevert(BaseHook.NotPoolManager.selector);
        hook.afterSwap(address(this), surchargePoolKey, params, BalanceDelta.wrap(0), _hookData(type(uint128).max));
    }

    function test_receive_directNativeTransfer_reverts() public {
        deal(address(this), 1 wei);

        vm.expectRevert(BaseHook.NotPoolManager.selector);
        this.sendNative{ value: 1 wei }(payable(address(hook)));
    }

    function sendNative(address payable recipient) external payable {
        (bool success, bytes memory returnData) = recipient.call{ value: msg.value }("");
        if (!success) {
            assembly ("memory-safe") {
                revert(add(returnData, 0x20), mload(returnData))
            }
        }
    }

    function test_constructor_rateAboveCap_reverts() public {
        uint16 invalidRate = hook.MAX_SURCHARGE_BPS() + 1;

        vm.expectRevert(
            abi.encodeWithSelector(
                IProvisionalSurchargeHook.SurchargeRateTooHigh.selector, invalidRate, hook.MAX_SURCHARGE_BPS()
            )
        );
        deployCodeTo(
            "src/hooks/FixedBpsProvisionalSurchargeHook.sol:FixedBpsProvisionalSurchargeHook",
            abi.encode(manager, invalidRate),
            _hookAddress(0x4D42)
        );
    }

    function test_exactInput_zeroForOne_escrowsCurrency1() public {
        _assertSuccessfulSwap(true, true, 1e15, currency1);
    }

    function test_exactInput_oneForZero_escrowsCurrency0() public {
        _assertSuccessfulSwap(false, true, 1e15, currency0);
    }

    function test_exactOutput_zeroForOne_escrowsCurrency0() public {
        _assertSuccessfulSwap(true, false, 1e15, currency0);
    }

    function test_exactOutput_oneForZero_escrowsCurrency1() public {
        _assertSuccessfulSwap(false, false, 1e15, currency1);
    }

    function test_exactInput_oneForZero_nativeOutput_escrowsNativeCurrency() public {
        deal(address(this), 10 ether);
        (PoolKey memory nativePoolKey, PoolId nativePoolId) = initPoolAndAddLiquidityETH(
            CurrencyLibrary.ADDRESS_ZERO, currency1, IHooks(address(hook)), 3000, SQRT_PRICE_1_1, 1 ether
        );
        uint256 hookBalanceBefore = address(hook).balance;

        vm.recordLogs();
        swapNativeInput(nativePoolKey, false, -int256(1e15), _hookData(type(uint128).max), 0);
        AccrualEvent memory accrual = _readAccrual(vm.getRecordedLogs());

        assertEq(accrual.poolId, PoolId.unwrap(nativePoolId));
        assertEq(accrual.currency, address(0));
        assertEq(address(hook).balance - hookBalanceBefore, accrual.surchargeAmount);
        assertEq(hook.poolAccruedSurcharge(PoolId.unwrap(nativePoolId), address(0)), accrual.surchargeAmount);
        assertEq(hook.totalAccruedSurcharge(address(0)), accrual.surchargeAmount);
        assertEq(manager.getNonzeroDeltaCount(), 0);
        assertEq(manager.currencyDelta(address(hook), CurrencyLibrary.ADDRESS_ZERO), 0);
    }

    function test_multiplePools_separatePoolAccountingAndAggregateCurrencyAccounting() public {
        (PoolKey memory secondPoolKey, PoolId secondPoolId) =
            initPoolAndAddLiquidity(currency0, currency1, IHooks(address(hook)), 500, SQRT_PRICE_1_1);

        AccrualEvent memory firstAccrual = _executeAndReadAccrual(surchargePoolKey, true, true, 1e15);
        AccrualEvent memory secondAccrual = _executeAndReadAccrual(secondPoolKey, true, true, 1e15);

        assertEq(
            hook.poolAccruedSurcharge(PoolId.unwrap(surchargePoolId), Currency.unwrap(currency1)),
            firstAccrual.surchargeAmount
        );
        assertEq(
            hook.poolAccruedSurcharge(PoolId.unwrap(secondPoolId), Currency.unwrap(currency1)),
            secondAccrual.surchargeAmount
        );
        assertEq(
            hook.totalAccruedSurcharge(Currency.unwrap(currency1)),
            uint256(firstAccrual.surchargeAmount) + secondAccrual.surchargeAmount
        );
        assertEq(currency1.balanceOf(address(hook)), hook.totalAccruedSurcharge(Currency.unwrap(currency1)));
    }

    function test_maximumBelowQuote_revertsWithoutAccrual() public {
        SwapParams memory params = _swapParams(true, true, 1e15);

        vm.expectPartialRevert(CustomRevert.WrappedError.selector);
        swapRouter.swap(
            surchargePoolKey,
            params,
            PoolSwapTest.TestSettings({ takeClaims: false, settleUsingBurn: false }),
            _hookData(0)
        );

        assertEq(hook.totalAccruedSurcharge(Currency.unwrap(currency0)), 0);
        assertEq(hook.totalAccruedSurcharge(Currency.unwrap(currency1)), 0);
    }

    function test_emptyHookData_revertsWithoutAccrual() public {
        SwapParams memory params = _swapParams(true, true, 1e15);

        vm.expectRevert(_wrappedHookError(abi.encodeWithSelector(SurchargeHookData.InvalidHookDataLength.selector, 0)));
        swapRouter.swap(
            surchargePoolKey,
            params,
            PoolSwapTest.TestSettings({ takeClaims: false, settleUsingBurn: false }),
            bytes("")
        );

        assertEq(hook.totalAccruedSurcharge(Currency.unwrap(currency0)), 0);
        assertEq(hook.totalAccruedSurcharge(Currency.unwrap(currency1)), 0);
    }

    function test_zeroRecipient_revertsWithoutAccrual() public {
        SwapParams memory params = _swapParams(true, true, 1e15);
        bytes memory hookData = abi.encode(address(0), type(uint128).max);

        vm.expectRevert(_wrappedHookError(abi.encodeWithSelector(SurchargeHookData.ZeroRebateRecipient.selector)));
        swapRouter.swap(
            surchargePoolKey, params, PoolSwapTest.TestSettings({ takeClaims: false, settleUsingBurn: false }), hookData
        );

        assertEq(hook.totalAccruedSurcharge(Currency.unwrap(currency0)), 0);
        assertEq(hook.totalAccruedSurcharge(Currency.unwrap(currency1)), 0);
    }

    function test_maximumBelowQuote_exposesCanonicalInnerError() public {
        uint128 basisAmount = 1e15;
        uint128 quotedAmount = SurchargeMath.quoteBps(basisAmount, SURCHARGE_BPS);
        SwapParams memory params = _swapParams(true, true, basisAmount);

        vm.prank(address(manager));
        vm.expectRevert(
            abi.encodeWithSelector(IProvisionalSurchargeHook.SurchargeExceedsMaximum.selector, quotedAmount, 0)
        );
        hook.afterSwap(
            address(swapRouter),
            surchargePoolKey,
            params,
            // `basisAmount` is the fixed value 1e15, well inside the int128 range.
            // forge-lint: disable-next-line(unsafe-typecast)
            toBalanceDelta(-int128(basisAmount), int128(basisAmount)),
            _hookData(0)
        );
    }

    function testFuzz_allSwapQuadrants_conserveBalances(uint96 rawAmount, uint8 rawQuadrant) public {
        uint128 amount = uint128(bound(rawAmount, 1e8, 1e15));
        uint8 quadrant = uint8(bound(rawQuadrant, 0, 3));
        bool zeroForOne = quadrant < 2;
        bool exactInput = quadrant % 2 == 0;
        Currency expectedCurrency =
            exactInput ? (zeroForOne ? currency1 : currency0) : (zeroForOne ? currency0 : currency1);

        _assertSuccessfulSwap(zeroForOne, exactInput, amount, expectedCurrency);
    }

    function _assertSuccessfulSwap(bool zeroForOne, bool exactInput, uint128 amount, Currency expectedCurrency)
        private
    {
        ParticipantBalances memory before0 = _participantBalances(currency0);
        ParticipantBalances memory before1 = _participantBalances(currency1);
        uint256 expectedCurrencyHookBalanceBefore = expectedCurrency.balanceOf(address(hook));

        vm.recordLogs();
        swapRouter.swap(
            surchargePoolKey,
            _swapParams(zeroForOne, exactInput, amount),
            PoolSwapTest.TestSettings({ takeClaims: false, settleUsingBurn: false }),
            _hookData(type(uint128).max)
        );
        AccrualEvent memory accrual = _readAccrual(vm.getRecordedLogs());

        assertEq(accrual.poolId, PoolId.unwrap(surchargePoolId));
        assertEq(accrual.swapSender, address(swapRouter));
        assertEq(accrual.rebateRecipient, REBATE_RECIPIENT);
        assertEq(accrual.currency, Currency.unwrap(expectedCurrency));
        assertEq(accrual.maximumAmount, type(uint128).max);
        assertEq(accrual.surchargeAmount, SurchargeMath.quoteBps(accrual.basisAmount, SURCHARGE_BPS));
        assertGt(accrual.surchargeAmount, 0);

        assertEq(expectedCurrency.balanceOf(address(hook)) - expectedCurrencyHookBalanceBefore, accrual.surchargeAmount);
        assertEq(
            hook.poolAccruedSurcharge(PoolId.unwrap(surchargePoolId), Currency.unwrap(expectedCurrency)),
            accrual.surchargeAmount
        );
        assertEq(hook.totalAccruedSurcharge(Currency.unwrap(expectedCurrency)), accrual.surchargeAmount);

        _assertConserved(before0, _participantBalances(currency0));
        _assertConserved(before1, _participantBalances(currency1));

        assertEq(manager.getNonzeroDeltaCount(), 0);
        assertEq(manager.currencyDelta(address(hook), currency0), 0);
        assertEq(manager.currencyDelta(address(hook), currency1), 0);
        assertEq(manager.currencyDelta(address(swapRouter), currency0), 0);
        assertEq(manager.currencyDelta(address(swapRouter), currency1), 0);
    }

    function _executeAndReadAccrual(PoolKey memory poolKey, bool zeroForOne, bool exactInput, uint128 amount)
        private
        returns (AccrualEvent memory accrual)
    {
        vm.recordLogs();
        swapRouter.swap(
            poolKey,
            _swapParams(zeroForOne, exactInput, amount),
            PoolSwapTest.TestSettings({ takeClaims: false, settleUsingBurn: false }),
            _hookData(type(uint128).max)
        );
        accrual = _readAccrual(vm.getRecordedLogs());
    }

    function _readAccrual(Vm.Log[] memory logs) private pure returns (AccrualEvent memory accrual) {
        for (uint256 i = 0; i < logs.length; ++i) {
            if (logs[i].topics.length != 4 || logs[i].topics[0] != ACCRUAL_EVENT_SIGNATURE) continue;

            (address currencyAddress, uint128 basisAmount, uint128 surchargeAmount, uint128 maximumAmount) =
                abi.decode(logs[i].data, (address, uint128, uint128, uint128));

            return AccrualEvent({
                poolId: logs[i].topics[1],
                swapSender: address(uint160(uint256(logs[i].topics[2]))),
                rebateRecipient: address(uint160(uint256(logs[i].topics[3]))),
                currency: currencyAddress,
                basisAmount: basisAmount,
                surchargeAmount: surchargeAmount,
                maximumAmount: maximumAmount
            });
        }

        revert("accrual event not found");
    }

    function _participantBalances(Currency currency) private view returns (ParticipantBalances memory balances) {
        balances = ParticipantBalances({
            user: currency.balanceOf(address(this)),
            manager: currency.balanceOf(address(manager)),
            hook: currency.balanceOf(address(hook)),
            router: currency.balanceOf(address(swapRouter))
        });
    }

    function _assertConserved(ParticipantBalances memory beforeBalances, ParticipantBalances memory afterBalances)
        private
        pure
    {
        uint256 beforeTotal = beforeBalances.user + beforeBalances.manager + beforeBalances.hook + beforeBalances.router;
        uint256 afterTotal = afterBalances.user + afterBalances.manager + afterBalances.hook + afterBalances.router;
        assertEq(afterTotal, beforeTotal);
    }

    function _swapParams(bool zeroForOne, bool exactInput, uint128 amount)
        private
        pure
        returns (SwapParams memory params)
    {
        params = SwapParams({
            zeroForOne: zeroForOne,
            amountSpecified: exactInput ? -int256(uint256(amount)) : int256(uint256(amount)),
            sqrtPriceLimitX96: zeroForOne ? MIN_PRICE_LIMIT : MAX_PRICE_LIMIT
        });
    }

    function _hookData(uint128 maximumAmount) private pure returns (bytes memory) {
        return SurchargeHookData.encode(
            SurchargeAuthorization({ rebateRecipient: REBATE_RECIPIENT, maximumAmount: maximumAmount })
        );
    }

    function _hookAddress(uint16 namespace) private pure returns (address) {
        uint160 flags = Hooks.AFTER_SWAP_FLAG | Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG;
        return address(flags | (uint160(namespace) << 144));
    }

    function _wrappedHookError(bytes memory reason) private view returns (bytes memory) {
        return abi.encodeWithSelector(
            CustomRevert.WrappedError.selector,
            address(hook),
            IHooks.afterSwap.selector,
            reason,
            abi.encodePacked(Hooks.HookCallFailed.selector)
        );
    }
}
