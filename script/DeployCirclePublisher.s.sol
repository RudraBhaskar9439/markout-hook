// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Script, console2 } from "forge-std/Script.sol";

import { CirclePythObservationPublisher } from "../src/circle/CirclePythObservationPublisher.sol";
import { ICircleMessageTransmitterV2 } from "../src/interfaces/ICircleMessageTransmitterV2.sol";
import { IPyth } from "../src/interfaces/IPyth.sol";
import { CirclePublisherConfig } from "../src/types/CircleTypes.sol";

/// @notice Deploys the unbound Pyth-backed observation publisher on Ethereum Sepolia.
contract DeployCirclePublisher is Script {
    uint256 private constant ETHEREUM_SEPOLIA_CHAIN_ID = 11_155_111;

    error UnexpectedChain(uint256 actual, uint256 expected);
    error MaximumPriceAgeOverflow(uint256 value);
    error DomainOverflow(uint256 value);

    function run() external returns (CirclePythObservationPublisher publisher) {
        if (block.chainid != ETHEREUM_SEPOLIA_CHAIN_ID) {
            revert UnexpectedChain(block.chainid, ETHEREUM_SEPOLIA_CHAIN_ID);
        }

        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        uint256 maximumPriceAge = vm.envUint("PYTH_MAXIMUM_PRICE_AGE");
        if (maximumPriceAge > type(uint64).max) revert MaximumPriceAgeOverflow(maximumPriceAge);

        CirclePublisherConfig memory config = CirclePublisherConfig({
            binder: vm.addr(privateKey),
            messageTransmitter: ICircleMessageTransmitterV2(vm.envAddress("SEPOLIA_CIRCLE_MESSAGE_TRANSMITTER")),
            pyth: IPyth(vm.envAddress("PYTH_CONTRACT")),
            priceId: vm.envBytes32("PYTH_PRICE_ID"),
            marketId: vm.envBytes32("MARKET_ID"),
            destinationDomain: _destinationDomain(),
            // The range check above proves this conversion is lossless.
            // forge-lint: disable-next-line(unsafe-typecast)
            maximumPriceAge: uint64(maximumPriceAge)
        });

        vm.startBroadcast(privateKey);
        publisher = new CirclePythObservationPublisher(config);
        vm.stopBroadcast();

        console2.log("Circle Pyth observation publisher", address(publisher));
        console2.log("One-time binder", config.binder);
        console2.log("Circle destination domain", config.destinationDomain);
        console2.logBytes32(config.marketId);
    }

    function _destinationDomain() private view returns (uint32 domain) {
        uint256 configured = vm.envUint("CIRCLE_DESTINATION_DOMAIN");
        if (configured > type(uint32).max) revert DomainOverflow(configured);
        // The explicit range check proves this conversion is lossless.
        // forge-lint: disable-next-line(unsafe-typecast)
        domain = uint32(configured);
    }
}
