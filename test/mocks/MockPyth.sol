// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IPyth, PythPrice } from "../../src/interfaces/IPyth.sol";

contract MockPyth is IPyth {
    error UnexpectedPriceId(bytes32 supplied, bytes32 expected);
    error IncorrectFee(uint256 supplied, uint256 expected);
    error StalePrice(uint256 publishTime, uint256 currentTime, uint256 maximumAge);

    bytes32 public immutable expectedPriceId;
    uint256 public updateFee;
    uint256 public updateCalls;
    uint256 public lastUpdateValue;

    PythPrice private _price;

    constructor(bytes32 expectedPriceId_) {
        expectedPriceId = expectedPriceId_;
    }

    function setUpdateFee(uint256 updateFee_) external {
        updateFee = updateFee_;
    }

    function setPrice(PythPrice memory price_) external {
        _price = price_;
    }

    function getUpdateFee(bytes[] calldata) external view returns (uint256 feeAmount) {
        return updateFee;
    }

    function updatePriceFeeds(bytes[] calldata) external payable {
        if (msg.value != updateFee) revert IncorrectFee(msg.value, updateFee);
        ++updateCalls;
        lastUpdateValue = msg.value;
    }

    function getPriceNoOlderThan(bytes32 id, uint256 age) external view returns (PythPrice memory price) {
        if (id != expectedPriceId) revert UnexpectedPriceId(id, expectedPriceId);
        price = _price;
        if (price.publishTime > block.timestamp || block.timestamp - price.publishTime > age) {
            revert StalePrice(price.publishTime, block.timestamp, age);
        }
    }
}
