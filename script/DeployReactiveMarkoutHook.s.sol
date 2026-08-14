// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Script, console2 } from "forge-std/Script.sol";

import { IPoolManager } from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import { Hooks } from "@uniswap/v4-core/src/libraries/Hooks.sol";
import { HookMiner } from "@uniswap/v4-periphery/src/utils/HookMiner.sol";

import { ReactiveMarkoutSettlementAdapter } from "../src/adapters/ReactiveMarkoutSettlementAdapter.sol";
import { MarkoutHook } from "../src/hooks/MarkoutHook.sol";

/// @notice Deploys and permanently wires MARKOUT's destination-chain callback topology.
/// @dev `reactiveIdentity` is the identity injected by the configured Reactive callback proxy.
contract DeployReactiveMarkoutHook is Script {
    address private constant CREATE2_DEPLOYER = 0x4e59b44847b379578588920cA78FbF26c0B4956C;
    uint256 private constant MAX_SUPPORTED_DECIMALS = 36;
    uint256 private constant MAX_SURCHARGE_BPS = 1000;

    error ZeroPoolManager();
    error ZeroCallbackProxy();
    error ZeroReactiveIdentity();
    error SameCurrency(address currency);
    error InvalidDecimals(uint256 decimals);
    error InvalidSurchargeBps(uint256 surchargeBps);
    error HookAddressMismatch(address predicted, address deployed);

    struct DeploymentConfig {
        IPoolManager poolManager;
        address callbackProxy;
        address reactiveIdentity;
        address baseCurrency;
        uint8 baseDecimals;
        address quoteCurrency;
        uint8 quoteDecimals;
        uint16 surchargeBps;
    }

    struct DeploymentResult {
        address deployer;
        ReactiveMarkoutSettlementAdapter adapter;
        MarkoutHook hook;
        bytes32 salt;
    }

    function run() external returns (DeploymentResult memory result) {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        DeploymentConfig memory config = DeploymentConfig({
            poolManager: IPoolManager(vm.envAddress("POOL_MANAGER")),
            callbackProxy: vm.envAddress("REACTIVE_CALLBACK_PROXY"),
            reactiveIdentity: vm.envAddress("REACTIVE_IDENTITY"),
            baseCurrency: vm.envAddress("BASE_CURRENCY"),
            baseDecimals: _validatedDecimals(vm.envUint("BASE_DECIMALS")),
            quoteCurrency: vm.envAddress("QUOTE_CURRENCY"),
            quoteDecimals: _validatedDecimals(vm.envUint("QUOTE_DECIMALS")),
            surchargeBps: _validatedSurchargeBps(vm.envUint("SURCHARGE_BPS"))
        });
        result = deploy(config, privateKey);

        console2.log("MARKOUT deployer", result.deployer);
        console2.log("Reactive settlement adapter", address(result.adapter));
        console2.log("MARKOUT hook", address(result.hook));
        console2.logBytes32(result.salt);
    }

    function deploy(DeploymentConfig memory config, uint256 privateKey)
        public
        returns (DeploymentResult memory result)
    {
        _validate(config);
        result.deployer = vm.addr(privateKey);

        vm.startBroadcast(privateKey);
        result.adapter =
            new ReactiveMarkoutSettlementAdapter(result.deployer, config.callbackProxy, config.reactiveIdentity);
        vm.stopBroadcast();

        bytes memory constructorArgs = abi.encode(
            config.poolManager,
            config.surchargeBps,
            address(result.adapter),
            config.baseCurrency,
            config.baseDecimals,
            config.quoteCurrency,
            config.quoteDecimals
        );
        uint160 flags = Hooks.AFTER_SWAP_FLAG | Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG;
        address predictedHook;
        (predictedHook, result.salt) =
            HookMiner.find(CREATE2_DEPLOYER, flags, type(MarkoutHook).creationCode, constructorArgs);

        vm.startBroadcast(privateKey);
        result.hook = new MarkoutHook{ salt: result.salt }(
            config.poolManager,
            config.surchargeBps,
            address(result.adapter),
            config.baseCurrency,
            config.baseDecimals,
            config.quoteCurrency,
            config.quoteDecimals
        );
        if (address(result.hook) != predictedHook) {
            revert HookAddressMismatch(predictedHook, address(result.hook));
        }
        result.adapter.bindTarget(result.hook);
        vm.stopBroadcast();
    }

    function _validate(DeploymentConfig memory config) private pure {
        if (address(config.poolManager) == address(0)) revert ZeroPoolManager();
        if (config.callbackProxy == address(0)) revert ZeroCallbackProxy();
        if (config.reactiveIdentity == address(0)) revert ZeroReactiveIdentity();
        if (config.baseCurrency == config.quoteCurrency) revert SameCurrency(config.baseCurrency);
    }

    function _validatedDecimals(uint256 decimals) private pure returns (uint8) {
        if (decimals > MAX_SUPPORTED_DECIMALS) revert InvalidDecimals(decimals);
        // The explicit validation above proves the conversion is lossless.
        // forge-lint: disable-next-line(unsafe-typecast)
        return uint8(decimals);
    }

    function _validatedSurchargeBps(uint256 surchargeBps) private pure returns (uint16) {
        if (surchargeBps > MAX_SURCHARGE_BPS) revert InvalidSurchargeBps(surchargeBps);
        // The explicit validation above proves the conversion is lossless.
        // forge-lint: disable-next-line(unsafe-typecast)
        return uint16(surchargeBps);
    }
}
