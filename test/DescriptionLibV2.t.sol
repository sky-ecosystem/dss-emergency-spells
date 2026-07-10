// SPDX-FileCopyrightText: © 2026 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {Test} from "forge-std/Test.sol";

import {DescriptionLibV2} from "../src/libraries/DescriptionLibV2.sol";

contract DescriptionLibV2Harness {
    function toString(bytes32 value) external pure returns (string memory) {
        return DescriptionLibV2.toString(value);
    }
}

contract DescriptionLibV2Test is Test {
    DescriptionLibV2Harness internal harness = new DescriptionLibV2Harness();

    function testConvertsEmptyValue() public view {
        assertEq(harness.toString(bytes32(0)), "");
    }

    function testConvertsNullTerminatedValue() public view {
        assertEq(harness.toString("ETH-A"), "ETH-A");
    }

    function testStopsAtFirstNullByte() public view {
        bytes32 value = 0x4554482d410058595a0000000000000000000000000000000000000000000000;
        assertEq(harness.toString(value), "ETH-A");
    }

    function testConvertsFullLengthValueWithoutReadingOutOfBounds() public view {
        bytes32 value = 0x3132333435363738393031323334353637383930313233343536373839303132;
        assertEq(harness.toString(value), "12345678901234567890123456789012");
    }
}
