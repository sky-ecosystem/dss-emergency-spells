// SPDX-FileCopyrightText: © 2026 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {Test} from "forge-std/Test.sol";

import {EmergencySpellBatchV2} from "../EmergencySpellBatchV2.sol";
import {StUsdsRateSetterHaltSpellV2} from "./StUsdsRateSetterHaltSpellV2.sol";

contract HaltRateSetterMockV2 {
    address public immutable stusds;
    uint8 public bad;

    constructor(address stUsds_) {
        stusds = stUsds_;
    }

    function halt() external {
        bad = 1;
    }
}

contract HaltRateSetterMomMockV2 {
    address public immutable stusds;
    mapping(address => bool) public authorized;
    address public lastCaller;

    constructor(address stUsds_) {
        stusds = stUsds_;
    }

    function rely(address caller) external {
        authorized[caller] = true;
    }

    function haltRateSetter(address rateSetter) external {
        require(authorized[msg.sender], "HaltRateSetterMomMockV2/not-authorized");
        lastCaller = msg.sender;
        HaltRateSetterMockV2(rateSetter).halt();
    }
}

contract InvalidHaltRateSetterV2 {}

contract StUsdsRateSetterHaltSpellV2Test is Test {
    address internal constant CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;
    bytes32 internal constant MCD_PAUSE = "MCD_PAUSE";

    address internal stUsds;
    HaltRateSetterMockV2 internal rateSetter;
    HaltRateSetterMomMockV2 internal stUsdsMom;
    StUsdsRateSetterHaltSpellV2 internal spell;

    function setUp() public {
        vm.mockCall(CHAINLOG, abi.encodeWithSignature("getAddress(bytes32)", MCD_PAUSE), abi.encode(makeAddr("pause")));
        stUsds = makeAddr("stUsds");
        rateSetter = new HaltRateSetterMockV2(stUsds);
        stUsdsMom = new HaltRateSetterMomMockV2(stUsds);
        spell = new StUsdsRateSetterHaltSpellV2(address(stUsdsMom), address(rateSetter));
    }

    function testMetadataAndInitialState() public view {
        assertEq(spell.description(), "Emergency Spell | stUSDS | Halt Rate Setter");
        assertEq(spell.stUsdsMom(), address(stUsdsMom));
        assertEq(spell.rateSetter(), address(rateSetter));
        assertEq(spell.stUsds(), stUsds);
        assertFalse(spell.done());
    }

    function testUnauthorizedExecutionDoesNotChangeState() public {
        vm.expectRevert("HaltRateSetterMomMockV2/not-authorized");
        spell.schedule();
        assertFalse(spell.done());
        assertEq(rateSetter.bad(), 0);
    }

    function testDirectExecutionIsRepeatable() public {
        stUsdsMom.rely(address(spell));
        spell.schedule();
        assertTrue(spell.done());
        spell.schedule();
        assertTrue(spell.done());
        assertEq(stUsdsMom.lastCaller(), address(spell));
    }

    function testBatchExecutionUsesBatchAsCaller() public {
        address[] memory leaves = new address[](1);
        leaves[0] = address(spell);
        EmergencySpellBatchV2 batch = new EmergencySpellBatchV2(leaves, "Halt rate setter");
        stUsdsMom.rely(address(batch));

        batch.schedule();

        assertTrue(spell.done());
        assertEq(stUsdsMom.lastCaller(), address(batch));
    }

    function testRejectsMismatchedObjectGraph() public {
        HaltRateSetterMockV2 other = new HaltRateSetterMockV2(makeAddr("other-stUsds"));
        vm.expectRevert("StUsdsRateSetterHaltSpellV2/stusds-mismatch");
        new StUsdsRateSetterHaltSpellV2(address(stUsdsMom), address(other));
    }

    function testMalformedRateSetterRevertsDuringConstruction() public {
        InvalidHaltRateSetterV2 invalid = new InvalidHaltRateSetterV2();
        vm.expectRevert();
        new StUsdsRateSetterHaltSpellV2(address(stUsdsMom), address(invalid));
    }
}
