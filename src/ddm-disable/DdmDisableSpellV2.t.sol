// SPDX-FileCopyrightText: © 2026 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {Test} from "forge-std/Test.sol";

import {EmergencySpellBatchV2} from "../EmergencySpellBatchV2.sol";
import {DdmDisableSpellV2} from "./DdmDisableSpellV2.sol";

contract DdmPlanLeafMockV2 {
    bool public active = true;

    function disable() external {
        active = false;
    }
}

contract DdmMomLeafMockV2 {
    mapping(address => bool) public authorized;
    address public lastCaller;

    function rely(address caller) external {
        authorized[caller] = true;
    }

    function disable(address plan) external {
        require(authorized[msg.sender], "DdmMomLeafMockV2/not-authorized");
        lastCaller = msg.sender;
        DdmPlanLeafMockV2(plan).disable();
    }
}

contract InvalidDdmPlanV2 {}

contract DdmDisableSpellV2Test is Test {
    address internal constant CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;
    bytes32 internal constant MCD_PAUSE = "MCD_PAUSE";
    bytes32 internal constant ILK = "DIRECT-SPARK-DAI";

    DdmPlanLeafMockV2 internal plan;
    DdmMomLeafMockV2 internal ddmMom;
    DdmDisableSpellV2 internal spell;

    function setUp() public {
        vm.mockCall(CHAINLOG, abi.encodeWithSignature("getAddress(bytes32)", MCD_PAUSE), abi.encode(makeAddr("pause")));
        plan = new DdmPlanLeafMockV2();
        ddmMom = new DdmMomLeafMockV2();
        spell = new DdmDisableSpellV2(address(ddmMom), address(plan), ILK);
    }

    function testMetadataAndInitialState() public view {
        assertEq(spell.description(), string(abi.encodePacked("Emergency Spell | Disable DDM Plan: ", ILK)));
        assertEq(spell.ddmMom(), address(ddmMom));
        assertEq(spell.plan(), address(plan));
        assertEq(spell.ilk(), ILK);
        assertFalse(spell.done());
    }

    function testUnauthorizedExecutionDoesNotChangeState() public {
        vm.expectRevert("DdmMomLeafMockV2/not-authorized");
        spell.schedule();
        assertFalse(spell.done());
        assertTrue(plan.active());
    }

    function testDirectExecutionIsRepeatable() public {
        ddmMom.rely(address(spell));
        spell.schedule();
        assertTrue(spell.done());
        spell.schedule();
        assertTrue(spell.done());
        assertEq(ddmMom.lastCaller(), address(spell));
    }

    function testBatchExecutionUsesBatchAsCaller() public {
        address[] memory leaves = new address[](1);
        leaves[0] = address(spell);
        EmergencySpellBatchV2 batch = new EmergencySpellBatchV2(leaves, "DDM disable");
        ddmMom.rely(address(batch));

        batch.schedule();

        assertTrue(spell.done());
        assertEq(ddmMom.lastCaller(), address(batch));
    }

    function testMalformedPlanRevertsInsteadOfReportingDone() public {
        DdmDisableSpellV2 broken = new DdmDisableSpellV2(address(ddmMom), address(new InvalidDdmPlanV2()), ILK);
        vm.expectRevert();
        broken.done();
    }
}
