// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @notice ABI-compatible subset of Pyth Core required by the Circle source publisher.
struct PythPrice {
    int64 price;
    uint64 conf;
    int32 expo;
    uint256 publishTime;
}

interface IPyth {
    function getUpdateFee(bytes[] calldata updateData) external view returns (uint256 feeAmount);

    function updatePriceFeeds(bytes[] calldata updateData) external payable;

    function getPriceNoOlderThan(bytes32 id, uint256 age) external view returns (PythPrice memory price);
}
