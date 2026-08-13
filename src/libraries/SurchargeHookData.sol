// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { SurchargeAuthorization } from "../types/SurchargeTypes.sol";

/// @title Surcharge Hook Data
/// @notice Canonical encoding and strict decoding for user surcharge constraints.
library SurchargeHookData {
    uint256 internal constant ENCODED_LENGTH = 64;

    /// @notice Hook data length is not the canonical two-word encoding.
    error InvalidHookDataLength(uint256 actualLength);

    /// @notice The address word contains non-zero padding outside its low 160 bits.
    error InvalidRecipientEncoding();

    /// @notice The maximum-amount word exceeds `uint128`.
    error InvalidMaximumAmountEncoding();

    /// @notice A zero rebate recipient was supplied.
    error ZeroRebateRecipient();

    /// @notice Encodes the canonical two-word payload expected by the hook.
    function encode(SurchargeAuthorization memory authorization) internal pure returns (bytes memory) {
        return abi.encode(authorization.rebateRecipient, authorization.maximumAmount);
    }

    /// @notice Decodes and validates a canonical surcharge authorization.
    /// @dev Strict length and padding checks make malformed payload failures deterministic.
    function decode(bytes calldata data) internal pure returns (SurchargeAuthorization memory authorization) {
        if (data.length != ENCODED_LENGTH) revert InvalidHookDataLength(data.length);

        uint256 recipientWord;
        uint256 maximumWord;
        assembly ("memory-safe") {
            recipientWord := calldataload(data.offset)
            maximumWord := calldataload(add(data.offset, 0x20))
        }

        if (recipientWord > type(uint160).max) revert InvalidRecipientEncoding();
        if (maximumWord > type(uint128).max) revert InvalidMaximumAmountEncoding();

        // The bounds check above proves the narrowing conversion is lossless.
        // forge-lint: disable-next-line(unsafe-typecast)
        address rebateRecipient = address(uint160(recipientWord));
        if (rebateRecipient == address(0)) revert ZeroRebateRecipient();

        // The bounds check above proves the narrowing conversion is lossless.
        // forge-lint: disable-next-line(unsafe-typecast)
        uint128 maximumAmount = uint128(maximumWord);
        authorization = SurchargeAuthorization({ rebateRecipient: rebateRecipient, maximumAmount: maximumAmount });
    }
}
