// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Script, console2 } from "forge-std/Script.sol";

import { IPoolManager } from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import { Hooks } from "@uniswap/v4-core/src/libraries/Hooks.sol";
import { HookMiner } from "@uniswap/v4-periphery/src/utils/HookMiner.sol";

import { CircleObservationReceiver } from "../src/circle/CircleObservationReceiver.sol";
import { MarkoutHook } from "../src/hooks/MarkoutHook.sol";
import { ICoordinatedMarkoutTarget } from "../src/interfaces/ICoordinatedMarkoutTarget.sol";
import { ReactiveObservationReceiver } from "../src/reactive/ReactiveObservationReceiver.sol";
import { SettlementCoordinator } from "../src/settlement/SettlementCoordinator.sol";
import { CircleReceiverConfig } from "../src/types/CircleTypes.sol";

/// @notice Deploys and permanently binds MARKOUT's complete Unichain hybrid destination topology.
contract DeployHybridDestination is Script {
    address private constant CREATE2_DEPLOYER = 0x4e59b44847b379578588920cA78FbF26c0B4956C;
    uint256 private constant UNICHAIN_SEPOLIA_CHAIN_ID = 1301;
    uint256 private constant MAX_SUPPORTED_DECIMALS = 36;
    uint256 private constant MAX_SURCHARGE_BPS = 1000;

    error UnexpectedChain(uint256 actual, uint256 expected);
    error ZeroAddress(string field);
    error SameCurrency(address currency);
    error InvalidDecimals(uint256 decimals);
    error InvalidSurchargeBps(uint256 surchargeBps);
    error DomainOverflow(uint256 domain);
    error HookAddressMismatch(address predicted, address deployed);

    struct DeploymentConfig {
        IPoolManager poolManager;
        address circleMessageTransmitter;
        uint32 circleSourceDomain;
        address circleSourcePublisher;
        address reactiveCallbackProxy;
        address reactiveIdentity;
        bytes32 marketId;
        address baseCurrency;
        uint8 baseDecimals;
        address quoteCurrency;
        uint8 quoteDecimals;
        uint16 surchargeBps;
    }

    struct DeploymentResult {
        address deployer;
        SettlementCoordinator coordinator;
        CircleObservationReceiver circleReceiver;
        ReactiveObservationReceiver reactiveReceiver;
        MarkoutHook hook;
        bytes32 hookSalt;
    }

    function run() external returns (DeploymentResult memory result) {
        if (block.chainid != UNICHAIN_SEPOLIA_CHAIN_ID) {
            revert UnexpectedChain(block.chainid, UNICHAIN_SEPOLIA_CHAIN_ID);
        }

        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        DeploymentConfig memory config = DeploymentConfig({
            poolManager: IPoolManager(vm.envAddress("POOL_MANAGER")),
            circleMessageTransmitter: vm.envAddress("UNICHAIN_CIRCLE_MESSAGE_TRANSMITTER"),
            circleSourceDomain: _sourceDomain(),
            circleSourcePublisher: vm.envAddress("CIRCLE_PUBLISHER"),
            reactiveCallbackProxy: vm.envAddress("REACTIVE_CALLBACK_PROXY"),
            reactiveIdentity: vm.envAddress("REACTIVE_IDENTITY"),
            marketId: vm.envBytes32("MARKET_ID"),
            baseCurrency: vm.envAddress("BASE_CURRENCY"),
            baseDecimals: _validatedDecimals(vm.envUint("BASE_DECIMALS")),
            quoteCurrency: vm.envAddress("QUOTE_CURRENCY"),
            quoteDecimals: _validatedDecimals(vm.envUint("QUOTE_DECIMALS")),
            surchargeBps: _validatedSurchargeBps(vm.envUint("SURCHARGE_BPS"))
        });
        result = deploy(config, privateKey);

        console2.log("Settlement coordinator", address(result.coordinator));
        console2.log("Circle observation receiver", address(result.circleReceiver));
        console2.log("Reactive observation receiver", address(result.reactiveReceiver));
        console2.log("MARKOUT hook", address(result.hook));
        console2.logBytes32(result.hookSalt);
    }

    function deploy(DeploymentConfig memory config, uint256 privateKey)
        public
        returns (DeploymentResult memory result)
    {
        _validate(config);
        result.deployer = vm.addr(privateKey);

        vm.startBroadcast(privateKey);
        result.coordinator = new SettlementCoordinator(result.deployer);
        result.circleReceiver = new CircleObservationReceiver(
            CircleReceiverConfig({
                messageTransmitter: config.circleMessageTransmitter,
                sourceDomain: config.circleSourceDomain,
                sourcePublisher: config.circleSourcePublisher,
                marketId: config.marketId,
                settlementCoordinator: result.coordinator
            })
        );
        result.reactiveReceiver = new ReactiveObservationReceiver(
            config.reactiveCallbackProxy, config.reactiveIdentity, config.marketId, result.coordinator
        );
        vm.stopBroadcast();

        bytes memory constructorArgs = abi.encode(
            config.poolManager,
            config.surchargeBps,
            address(result.coordinator),
            config.baseCurrency,
            config.baseDecimals,
            config.quoteCurrency,
            config.quoteDecimals
        );
        uint160 flags = Hooks.AFTER_SWAP_FLAG | Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG;
        address predictedHook;
        (predictedHook, result.hookSalt) =
            HookMiner.find(CREATE2_DEPLOYER, flags, type(MarkoutHook).creationCode, constructorArgs);

        vm.startBroadcast(privateKey);
        result.hook = new MarkoutHook{ salt: result.hookSalt }(
            config.poolManager,
            config.surchargeBps,
            address(result.coordinator),
            config.baseCurrency,
            config.baseDecimals,
            config.quoteCurrency,
            config.quoteDecimals
        );
        if (address(result.hook) != predictedHook) {
            revert HookAddressMismatch(predictedHook, address(result.hook));
        }

        address[] memory sources = new address[](2);
        sources[0] = address(result.circleReceiver);
        sources[1] = address(result.reactiveReceiver);
        result.coordinator.bindTopology(ICoordinatedMarkoutTarget(address(result.hook)), sources);
        vm.stopBroadcast();
    }

    function _validate(DeploymentConfig memory config) private pure {
        if (address(config.poolManager) == address(0)) revert ZeroAddress("POOL_MANAGER");
        if (config.circleMessageTransmitter == address(0)) revert ZeroAddress("UNICHAIN_CIRCLE_MESSAGE_TRANSMITTER");
        if (config.circleSourcePublisher == address(0)) revert ZeroAddress("CIRCLE_PUBLISHER");
        if (config.reactiveCallbackProxy == address(0)) revert ZeroAddress("REACTIVE_CALLBACK_PROXY");
        if (config.reactiveIdentity == address(0)) revert ZeroAddress("REACTIVE_IDENTITY");
        if (config.marketId == bytes32(0)) revert ZeroAddress("MARKET_ID");
        if (config.baseCurrency == address(0)) revert ZeroAddress("BASE_CURRENCY");
        if (config.quoteCurrency == address(0)) revert ZeroAddress("QUOTE_CURRENCY");
        if (config.baseCurrency == config.quoteCurrency) revert SameCurrency(config.baseCurrency);
    }

    function _sourceDomain() private view returns (uint32 domain) {
        uint256 configured = vm.envUint("CIRCLE_SOURCE_DOMAIN");
        if (configured > type(uint32).max) revert DomainOverflow(configured);
        // The explicit range check proves this conversion is lossless.
        // forge-lint: disable-next-line(unsafe-typecast)
        domain = uint32(configured);
    }

    function _validatedDecimals(uint256 decimals) private pure returns (uint8) {
        if (decimals > MAX_SUPPORTED_DECIMALS) revert InvalidDecimals(decimals);
        // The explicit validation above proves this conversion is lossless.
        // forge-lint: disable-next-line(unsafe-typecast)
        return uint8(decimals);
    }

    function _validatedSurchargeBps(uint256 surchargeBps) private pure returns (uint16) {
        if (surchargeBps > MAX_SURCHARGE_BPS) revert InvalidSurchargeBps(surchargeBps);
        // The explicit validation above proves this conversion is lossless.
        // forge-lint: disable-next-line(unsafe-typecast)
        return uint16(surchargeBps);
    }
}
