// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { AuthenticatedReactiveCallback } from "../base/AuthenticatedReactiveCallback.sol";

/// @title Reactive Callback Canary
/// @notice Emits deterministic test requests and records authenticated Reactive Network callbacks.
/// @dev Deploy this contract on the origin/destination chain before deploying the Reactive scheduler.
contract ReactiveCallbackCanary is AuthenticatedReactiveCallback {
    error UnknownRequest(uint256 requestId);

    event CanaryRequested(uint256 indexed requestId, address indexed requester, uint64 requestedAt);
    event CanaryCallbackReceived(
        uint256 indexed requestId, address indexed reactiveIdentity, uint256 originBlockNumber, uint64 receivedAt
    );
    event DuplicateCanaryCallbackIgnored(uint256 indexed requestId);

    uint256 public requestCount;
    uint256 public callbackCount;

    mapping(uint256 requestId => bool received) public callbackReceived;
    mapping(uint256 requestId => uint256 blockNumber) public callbackOriginBlock;

    constructor(address callbackSender_, address reactiveIdentity_)
        AuthenticatedReactiveCallback(callbackSender_, reactiveIdentity_)
    { }

    /// @notice Emits one uniquely numbered event for the Reactive scheduler to observe.
    function requestCallback() external returns (uint256 requestId) {
        requestId = ++requestCount;
        emit CanaryRequested(requestId, msg.sender, _currentTimestamp());
    }

    /// @notice Records a callback delivered by the configured proxy and Reactive identity.
    /// @dev Duplicate delivery is deliberately idempotent so a relayer retry cannot corrupt the result.
    function receiveCallback(address suppliedReactiveIdentity, uint256 requestId, uint256 originBlockNumber)
        external
        onlyAuthenticatedReactiveCallback(suppliedReactiveIdentity)
    {
        if (requestId == 0 || requestId > requestCount) revert UnknownRequest(requestId);
        if (callbackReceived[requestId]) {
            emit DuplicateCanaryCallbackIgnored(requestId);
            return;
        }

        callbackReceived[requestId] = true;
        callbackOriginBlock[requestId] = originBlockNumber;
        ++callbackCount;

        emit CanaryCallbackReceived(requestId, suppliedReactiveIdentity, originBlockNumber, _currentTimestamp());
    }

    function _currentTimestamp() private view returns (uint64 timestamp) {
        // EVM timestamps cannot approach uint64's limit in any realistic deployment lifetime.
        // forge-lint: disable-next-line(unsafe-typecast)
        timestamp = uint64(block.timestamp);
    }
}
