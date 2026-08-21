// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { PythPrice } from "../../src/interfaces/IPyth.sol";
import { PythObservation } from "../../src/libraries/PythObservation.sol";
import { ReferenceObservation } from "../../src/types/MarkoutTypes.sol";

contract PythObservationHarness {
    function normalize(PythPrice memory pythPrice) external pure returns (ReferenceObservation memory) {
        return PythObservation.normalize(pythPrice);
    }
}
