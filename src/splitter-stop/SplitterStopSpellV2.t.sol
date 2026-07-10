// SPDX-FileCopyrightText: © 2026 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {Test} from "forge-std/Test.sol";

import {EmergencySpellBatchV2} from "../EmergencySpellBatchV2.sol";
import {SplitterStopSpellV2} from "./SplitterStopSpellV2.sol";

contract SplitterLeafMockV2 {
    uint256 public hop = 1 days;

    function stop() external {
        hop = type(uint256).max;
    }
}

contract SplitterMomLeafMockV2 {
    address public immutable splitter;
    mapping(address => bool) public authorized;
    address public lastCaller;

    constructor(address splitter_) {
        splitter = splitter_;
    }

    function rely(address caller) external {
        authorized[caller] = true;
    }

    function stop() external {
        require(authorized[msg.sender], "SplitterMomLeafMockV2/not-authorized");
        lastCaller = msg.sender;
        SplitterLeafMockV2(splitter).stop();
    }
}

contract InvalidSplitterV2 {}

contract SplitterStopSpellV2Test is Test {
    address internal constant CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;
    bytes32 internal constant MCD_PAUSE = "MCD_PAUSE";

    SplitterLeafMockV2 internal splitter;
    SplitterMomLeafMockV2 internal splitterMom;
    SplitterStopSpellV2 internal spell;

    function setUp() public {
        vm.mockCall(CHAINLOG, abi.encodeWithSignature("getAddress(bytes32)", MCD_PAUSE), abi.encode(makeAddr("pause")));
        splitter = new SplitterLeafMockV2();
        splitterMom = new SplitterMomLeafMockV2(address(splitter));
        spell = new SplitterStopSpellV2(address(splitterMom), address(splitter));
    }

    function testMetadataAndInitialState() public view {
        assertEq(spell.description(), "Emergency Spell | Stop Splitter");
        assertEq(spell.splitterMom(), address(splitterMom));
        assertEq(spell.splitter(), address(splitter));
        assertFalse(spell.done());
    }

    function testUnauthorizedExecutionDoesNotChangeState() public {
        vm.expectRevert("SplitterMomLeafMockV2/not-authorized");
        spell.schedule();
        assertFalse(spell.done());
        assertEq(splitter.hop(), 1 days);
    }

    function testDirectExecutionIsRepeatable() public {
        splitterMom.rely(address(spell));
        spell.schedule();
        assertTrue(spell.done());
        spell.schedule();
        assertTrue(spell.done());
        assertEq(splitterMom.lastCaller(), address(spell));
    }

    function testBatchExecutionUsesBatchAsCaller() public {
        address[] memory leaves = new address[](1);
        leaves[0] = address(spell);
        EmergencySpellBatchV2 batch = new EmergencySpellBatchV2(leaves, "Splitter stop");
        splitterMom.rely(address(batch));

        batch.schedule();

        assertTrue(spell.done());
        assertEq(splitterMom.lastCaller(), address(batch));
    }

    function testRejectsMismatchedObjectGraph() public {
        SplitterLeafMockV2 other = new SplitterLeafMockV2();
        vm.expectRevert("SplitterStopSpellV2/splitter-mismatch");
        new SplitterStopSpellV2(address(splitterMom), address(other));
    }

    function testMalformedSplitterRevertsInsteadOfReportingDone() public {
        InvalidSplitterV2 invalid = new InvalidSplitterV2();
        SplitterMomLeafMockV2 invalidMom = new SplitterMomLeafMockV2(address(invalid));
        SplitterStopSpellV2 broken = new SplitterStopSpellV2(address(invalidMom), address(invalid));
        vm.expectRevert();
        broken.done();
    }
}
