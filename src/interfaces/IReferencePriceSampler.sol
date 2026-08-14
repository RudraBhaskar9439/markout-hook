// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @notice Callback surface that produces a normalized reference-price event on demand.
interface IReferencePriceSampler {
    /// @dev Reactive Network overwrites the first argument with its authenticated deployer identity.
    function sample(address suppliedReactiveIdentity) external;
}
