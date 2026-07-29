// SPDX-FileCopyrightText: © 2026 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {Test} from "forge-std/Test.sol";

import {EmergencySpellBatchV2} from "../EmergencySpellBatchV2.sol";
import {SPBEAMHaltSpellV2} from "./SPBEAMHaltSpellV2.sol";

contract SPBEAMLeafMockV2 {
    uint256 public bad;

    function halt() external {
        bad = 1;
    }
}

contract SPBEAMMomLeafMockV2 {
    mapping(address => bool) public authorized;
    address public lastCaller;

    function rely(address caller) external {
        authorized[caller] = true;
    }

    function halt(address spbeam) external {
        require(authorized[msg.sender], "SPBEAMMomLeafMockV2/not-authorized");
        lastCaller = msg.sender;
        SPBEAMLeafMockV2(spbeam).halt();
    }
}

contract InvalidSPBEAMV2 {}

contract SPBEAMHaltSpellV2Test is Test {
    address internal constant CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;
    bytes32 internal constant MCD_PAUSE = "MCD_PAUSE";

    SPBEAMLeafMockV2 internal spbeam;
    SPBEAMMomLeafMockV2 internal spbeamMom;
    SPBEAMHaltSpellV2 internal spell;

    function setUp() public {
        vm.mockCall(CHAINLOG, abi.encodeWithSignature("getAddress(bytes32)", MCD_PAUSE), abi.encode(makeAddr("pause")));
        spbeam = new SPBEAMLeafMockV2();
        spbeamMom = new SPBEAMMomLeafMockV2();
        spell = new SPBEAMHaltSpellV2(address(spbeamMom), address(spbeam));
    }

    function testMetadataAndInitialState() public view {
        assertEq(spell.description(), "Emergency Spell | Halt SPBEAM");
        assertEq(spell.spbeamMom(), address(spbeamMom));
        assertEq(spell.spbeam(), address(spbeam));
        assertFalse(spell.done());
    }

    function testUnauthorizedExecutionDoesNotChangeState() public {
        vm.expectRevert("SPBEAMMomLeafMockV2/not-authorized");
        spell.schedule();
        assertFalse(spell.done());
        assertEq(spbeam.bad(), 0);
    }

    function testDirectExecutionIsRepeatable() public {
        spbeamMom.rely(address(spell));
        spell.schedule();
        assertTrue(spell.done());
        spell.schedule();
        assertTrue(spell.done());
        assertEq(spbeamMom.lastCaller(), address(spell));
    }

    function testBatchExecutionUsesBatchAsCaller() public {
        address[] memory leaves = new address[](1);
        leaves[0] = address(spell);
        EmergencySpellBatchV2 batch = new EmergencySpellBatchV2(leaves, "SPBEAM halt");
        spbeamMom.rely(address(batch));

        batch.schedule();

        assertTrue(spell.done());
        assertEq(spbeamMom.lastCaller(), address(batch));
    }

    function testMalformedSPBEAMRevertsInsteadOfReportingDone() public {
        SPBEAMHaltSpellV2 broken = new SPBEAMHaltSpellV2(address(spbeamMom), address(new InvalidSPBEAMV2()));
        vm.expectRevert();
        broken.done();
    }
}
