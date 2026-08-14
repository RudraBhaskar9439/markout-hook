// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Test } from "forge-std/Test.sol";

import { AuthenticatedReactiveCallback } from "../../src/base/AuthenticatedReactiveCallback.sol";
import { INormalizedReferencePriceFeed } from "../../src/interfaces/INormalizedReferencePriceFeed.sol";
import { UniswapV3MedianReferenceSampler } from "../../src/reference/UniswapV3MedianReferenceSampler.sol";
import { UniswapV3MedianSamplerConfig } from "../../src/types/ReferenceSamplerTypes.sol";
import { MockUniswapV3PoolReference } from "../mocks/MockUniswapV3PoolReference.sol";

contract UniswapV3MedianReferenceSamplerTest is Test {
    uint160 private constant Q96 = 1 << 96;
    address private constant BASE = address(1);
    address private constant QUOTE = address(2);
    address private constant CALLBACK_PROXY = address(0xCA11);
    address private constant REACTIVE_IDENTITY = address(0xBEEF);
    bytes32 private constant MARKET_ID = keccak256("BASE/QUOTE");

    MockUniswapV3PoolReference[3] private pools;
    UniswapV3MedianReferenceSampler private sampler;

    function setUp() public {
        pools[0] = new MockUniswapV3PoolReference(BASE, QUOTE, 10 * Q96, 1_000_000);
        pools[1] = new MockUniswapV3PoolReference(BASE, QUOTE, uint160((uint256(Q96) * 201) / 20), 1_000_000);
        pools[2] = new MockUniswapV3PoolReference(BASE, QUOTE, uint160((uint256(Q96) * 101) / 10), 1_000_000);
        sampler = new UniswapV3MedianReferenceSampler(_config());
    }

    function test_authenticatedSample_emitsMedianAndDispersionDerivedConfidence() public {
        vm.warp(1234);
        vm.expectEmit(true, false, false, true, address(sampler));
        emit INormalizedReferencePriceFeed.NormalizedReferencePricePublished(
            MARKET_ID, 101_002_499_999_999_999_999, 1234, 9901
        );

        vm.prank(CALLBACK_PROXY);
        sampler.sample(REACTIVE_IDENTITY);
    }

    function test_directCallerAndWrongIdentity_revert() public {
        vm.expectRevert(
            abi.encodeWithSelector(AuthenticatedReactiveCallback.UnauthorizedCallbackSender.selector, address(this))
        );
        sampler.sample(REACTIVE_IDENTITY);

        vm.prank(CALLBACK_PROXY);
        vm.expectRevert(
            abi.encodeWithSelector(
                AuthenticatedReactiveCallback.UnauthorizedReactiveIdentity.selector, address(0xBAD), REACTIVE_IDENTITY
            )
        );
        sampler.sample(address(0xBAD));
    }

    function test_insufficientLiquidity_reverts() public {
        pools[1].setLiquidity(0);
        vm.prank(CALLBACK_PROXY);
        vm.expectRevert(
            abi.encodeWithSelector(
                UniswapV3MedianReferenceSampler.InsufficientPoolLiquidity.selector,
                address(pools[1]),
                uint128(0),
                uint128(1)
            )
        );
        sampler.sample(REACTIVE_IDENTITY);
    }

    function test_callbackProxyCanCollectFundedDestinationGasPayment() public {
        vm.deal(address(this), 1 ether);
        (bool funded,) = payable(address(sampler)).call{ value: 1 ether }("");
        assertTrue(funded);

        uint256 proxyBalanceBefore = CALLBACK_PROXY.balance;
        vm.prank(CALLBACK_PROXY);
        sampler.pay(0.25 ether);

        assertEq(address(sampler).balance, 0.75 ether);
        assertEq(CALLBACK_PROXY.balance - proxyBalanceBefore, 0.25 ether);
    }

    function test_excessiveDispersion_reverts() public {
        pools[2].setSqrtPriceX96(20 * Q96);
        vm.prank(CALLBACK_PROXY);
        vm.expectRevert(
            abi.encodeWithSelector(
                UniswapV3MedianReferenceSampler.ExcessivePoolDispersion.selector, uint256(29_602), uint16(1000)
            )
        );
        sampler.sample(REACTIVE_IDENTITY);
    }

    function test_constructorRejectsDuplicateOrUnexpectedPools() public {
        UniswapV3MedianSamplerConfig memory config = _config();
        config.pools[2] = config.pools[1];
        vm.expectRevert(abi.encodeWithSelector(UniswapV3MedianReferenceSampler.DuplicatePool.selector, config.pools[1]));
        new UniswapV3MedianReferenceSampler(config);

        MockUniswapV3PoolReference wrong = new MockUniswapV3PoolReference(BASE, address(3), Q96, 1_000_000);
        config = _config();
        config.pools[2] = address(wrong);
        vm.expectRevert(
            abi.encodeWithSelector(
                UniswapV3MedianReferenceSampler.UnexpectedPoolPair.selector, address(wrong), BASE, address(3)
            )
        );
        new UniswapV3MedianReferenceSampler(config);
    }

    function _config() private view returns (UniswapV3MedianSamplerConfig memory config) {
        address[3] memory poolAddresses = [address(pools[0]), address(pools[1]), address(pools[2])];
        config = UniswapV3MedianSamplerConfig({
            callbackSender: CALLBACK_PROXY,
            reactiveIdentity: REACTIVE_IDENTITY,
            marketId: MARKET_ID,
            baseToken: BASE,
            baseDecimals: 18,
            quoteToken: QUOTE,
            quoteDecimals: 18,
            pools: poolAddresses,
            minimumLiquidity: 1,
            maximumDispersionBps: 1000
        });
    }
}
