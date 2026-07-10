// SPDX-FileCopyrightText: © 2026 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {Test} from "forge-std/Test.sol";

import {GlobalOsmStopSpellV2} from "../../src/osm-stop/GlobalOsmStopSpellV2.sol";
import {
    IlkRegistryMockV2,
    MalformedGlobalTargetV2,
    OsmGlobalMockV2,
    OsmMomGlobalMockV2,
    RevertingOsmGlobalMockV2
} from "../mocks/GlobalSpellMocksV2.sol";

contract GlobalOsmStopSpellV2Test is Test {
    address internal constant CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;
    bytes32 internal constant MCD_PAUSE = "MCD_PAUSE";
    bytes32 internal constant ILK_A = "ILK-A";
    bytes32 internal constant ILK_B = "ILK-B";
    bytes32 internal constant ILK_C = "ILK-C";
    bytes32 internal constant ILK_D = "ILK-D";

    IlkRegistryMockV2 internal registry;
    OsmMomGlobalMockV2 internal osmMom;

    event Stop(bytes32 indexed ilk, address indexed osm);

    function setUp() public {
        registry = new IlkRegistryMockV2();
        osmMom = new OsmMomGlobalMockV2();
        MalformedGlobalTargetV2 pause = new MalformedGlobalTargetV2();
        vm.mockCall(CHAINLOG, abi.encodeWithSignature("getAddress(bytes32)", MCD_PAUSE), abi.encode(address(pause)));
    }

    function testMetadata() public {
        GlobalOsmStopSpellV2 spell = _deploy();

        assertEq(spell.description(), "Emergency Spell | Global OSM Stop");
        assertEq(spell.ilkRegistry(), address(registry));
        assertEq(spell.osmMom(), address(osmMom));
    }

    function testCoversExistingAndLaterEnrollment() public {
        OsmGlobalMockV2 osmA = new OsmGlobalMockV2();
        _addOsm(ILK_A, address(osmA));
        GlobalOsmStopSpellV2 spell = _deploy();

        assertFalse(spell.done());
        vm.expectEmit(true, true, false, true, address(spell));
        emit Stop(ILK_A, address(osmA));
        spell.schedule();
        assertEq(osmA.stopped(), 1);
        assertTrue(spell.done());

        OsmGlobalMockV2 osmB = new OsmGlobalMockV2();
        _addOsm(ILK_B, address(osmB));
        assertFalse(spell.done());
        vm.expectEmit(true, true, false, true, address(spell));
        emit Stop(ILK_B, address(osmB));
        spell.schedule();
        assertEq(osmB.stopped(), 1);
        assertTrue(spell.done());

        spell.schedule();
        assertTrue(spell.done());
    }

    function testSkipsZeroOsmEntries() public {
        registry.add(ILK_A);
        GlobalOsmStopSpellV2 spell = _deploy();

        assertTrue(spell.done());
        spell.schedule();
        assertTrue(spell.done());
    }

    function testEmptyRegistryFullCallIsNoOpAndRangeReverts() public {
        GlobalOsmStopSpellV2 spell = _deploy();

        assertTrue(spell.done());
        spell.schedule();
        assertTrue(spell.done());

        vm.expectRevert("GlobalOsmStopSpellV2/empty-registry");
        spell.scheduleRange(0, 0);
    }

    function testRangeIsInclusiveAndCapsEnd() public {
        OsmGlobalMockV2 osmA = new OsmGlobalMockV2();
        OsmGlobalMockV2 osmB = new OsmGlobalMockV2();
        OsmGlobalMockV2 osmC = new OsmGlobalMockV2();
        OsmGlobalMockV2 osmD = new OsmGlobalMockV2();
        _addOsm(ILK_A, address(osmA));
        _addOsm(ILK_B, address(osmB));
        _addOsm(ILK_C, address(osmC));
        _addOsm(ILK_D, address(osmD));
        GlobalOsmStopSpellV2 spell = _deploy();

        spell.scheduleRange(1, 2);
        assertEq(osmA.stopped(), 0);
        assertEq(osmB.stopped(), 1);
        assertEq(osmC.stopped(), 1);
        assertEq(osmD.stopped(), 0);

        spell.scheduleRange(3, type(uint256).max);
        assertEq(osmD.stopped(), 1);
        assertFalse(spell.done());

        spell.scheduleRange(0, 0);
        assertTrue(spell.done());
    }

    function testRangeRejectsInvalidBounds() public {
        _addOsm(ILK_A, address(new OsmGlobalMockV2()));
        _addOsm(ILK_B, address(new OsmGlobalMockV2()));
        GlobalOsmStopSpellV2 spell = _deploy();

        vm.expectRevert("GlobalOsmStopSpellV2/start-out-of-bounds");
        spell.scheduleRange(2, 2);
        vm.expectRevert("GlobalOsmStopSpellV2/invalid-range");
        spell.scheduleRange(1, 0);
    }

    function testMalformedCoveredTargetReverts() public {
        MalformedGlobalTargetV2 malformed = new MalformedGlobalTargetV2();
        _addOsm(ILK_A, address(malformed));
        GlobalOsmStopSpellV2 spell = _deploy();

        vm.expectRevert();
        spell.done();
        vm.expectRevert();
        spell.schedule();
    }

    function testFullAndRangeCallsRollbackAtomically() public {
        OsmGlobalMockV2 osmA = new OsmGlobalMockV2();
        RevertingOsmGlobalMockV2 osmB = new RevertingOsmGlobalMockV2();
        _addOsm(ILK_A, address(osmA));
        _addOsm(ILK_B, address(osmB));
        GlobalOsmStopSpellV2 spell = _deploy();

        vm.expectRevert("RevertingOsmGlobalMockV2/stop-failed");
        spell.schedule();
        assertEq(osmA.stopped(), 0);

        vm.expectRevert("RevertingOsmGlobalMockV2/stop-failed");
        spell.scheduleRange(0, 1);
        assertEq(osmA.stopped(), 0);
    }

    function testUnauthorizedExecutionRevertsWithoutPartialEffects() public {
        OsmGlobalMockV2 osmA = new OsmGlobalMockV2();
        OsmGlobalMockV2 osmB = new OsmGlobalMockV2();
        _addOsm(ILK_A, address(osmA));
        _addOsm(ILK_B, address(osmB));
        GlobalOsmStopSpellV2 spell = new GlobalOsmStopSpellV2(address(registry), address(osmMom));

        vm.expectRevert("OsmMomGlobalMockV2/not-authorized");
        spell.schedule();
        assertEq(osmA.stopped(), 0);
        assertEq(osmB.stopped(), 0);
    }

    function _deploy() internal returns (GlobalOsmStopSpellV2 spell) {
        spell = new GlobalOsmStopSpellV2(address(registry), address(osmMom));
        osmMom.rely(address(spell));
    }

    function _addOsm(bytes32 ilk, address osm) internal {
        registry.add(ilk);
        osmMom.setOsm(ilk, osm);
    }
}
