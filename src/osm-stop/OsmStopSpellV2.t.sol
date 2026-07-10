// SPDX-FileCopyrightText: © 2026 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {Test} from "forge-std/Test.sol";

import {EmergencySpellBatchV2} from "../EmergencySpellBatchV2.sol";
import {OsmStopSpellV2} from "./OsmStopSpellV2.sol";

contract OsmLeafTargetMockV2 {
    uint256 public stopped;

    function stop() external {
        stopped = 1;
    }
}

contract OsmMomLeafMockV2 {
    mapping(bytes32 => address) public osms;
    mapping(address => bool) public authorized;
    address public lastCaller;

    function rely(address caller) external {
        authorized[caller] = true;
    }

    function setOsm(bytes32 ilk, address osm) external {
        osms[ilk] = osm;
    }

    function stop(bytes32 ilk) external {
        require(authorized[msg.sender], "OsmMomLeafMockV2/not-authorized");
        lastCaller = msg.sender;
        OsmLeafTargetMockV2(osms[ilk]).stop();
    }
}

contract InvalidOsmTargetV2 {}

contract OsmStopSpellV2Test is Test {
    address internal constant CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;
    bytes32 internal constant MCD_PAUSE = "MCD_PAUSE";
    bytes32 internal constant ILK = "ETH-A";

    OsmLeafTargetMockV2 internal osm;
    OsmMomLeafMockV2 internal osmMom;
    OsmStopSpellV2 internal spell;

    function setUp() public {
        vm.mockCall(CHAINLOG, abi.encodeWithSignature("getAddress(bytes32)", MCD_PAUSE), abi.encode(makeAddr("pause")));
        osm = new OsmLeafTargetMockV2();
        osmMom = new OsmMomLeafMockV2();
        osmMom.setOsm(ILK, address(osm));
        spell = new OsmStopSpellV2(address(osmMom), address(osm), ILK);
    }

    function testMetadataAndInitialState() public view {
        assertEq(spell.description(), string(abi.encodePacked("Emergency Spell | OSM Stop: ", ILK)));
        assertEq(spell.osmMom(), address(osmMom));
        assertEq(spell.osm(), address(osm));
        assertEq(spell.ilk(), ILK);
        assertFalse(spell.done());
    }

    function testUnauthorizedExecutionDoesNotChangeState() public {
        vm.expectRevert("OsmMomLeafMockV2/not-authorized");
        spell.schedule();
        assertFalse(spell.done());
        assertEq(osm.stopped(), 0);
    }

    function testDirectExecutionIsRepeatable() public {
        osmMom.rely(address(spell));
        spell.schedule();
        assertTrue(spell.done());
        spell.schedule();
        assertTrue(spell.done());
        assertEq(osmMom.lastCaller(), address(spell));
    }

    function testBatchExecutionUsesBatchAsCaller() public {
        address[] memory leaves = new address[](1);
        leaves[0] = address(spell);
        EmergencySpellBatchV2 batch = new EmergencySpellBatchV2(leaves, "OSM stop");
        osmMom.rely(address(batch));

        batch.schedule();

        assertTrue(spell.done());
        assertEq(osmMom.lastCaller(), address(batch));
    }

    function testChangedRegistrationRevertsWithoutStoppingEitherOsm() public {
        OsmLeafTargetMockV2 replacement = new OsmLeafTargetMockV2();
        osmMom.setOsm(ILK, address(replacement));
        osmMom.rely(address(spell));

        vm.expectRevert("OsmStopSpellV2/osm-mismatch");
        spell.schedule();

        assertFalse(spell.done());
        assertEq(osm.stopped(), 0);
        assertEq(replacement.stopped(), 0);
    }

    function testMalformedOsmRevertsInsteadOfReportingDone() public {
        OsmStopSpellV2 broken = new OsmStopSpellV2(address(osmMom), address(new InvalidOsmTargetV2()), ILK);
        vm.expectRevert();
        broken.done();
    }
}
