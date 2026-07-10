// SPDX-FileCopyrightText: © 2026 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {Test} from "forge-std/Test.sol";

import {GlobalClipBreakerSpellV2} from "./GlobalClipBreakerSpellV2.sol";
import {
    ClipGlobalMockV2,
    ClipperMomGlobalMockV2,
    IlkRegistryMockV2,
    MalformedGlobalTargetV2,
    PermissiveClipGlobalMockV2,
    RevertingClipGlobalMockV2
} from "../GlobalSpellMocksV2.t.sol";

contract GlobalClipBreakerSpellV2Test is Test {
    address internal constant CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;
    bytes32 internal constant MCD_PAUSE = "MCD_PAUSE";
    bytes32 internal constant ILK_A = "ILK-A";
    bytes32 internal constant ILK_B = "ILK-B";
    bytes32 internal constant ILK_C = "ILK-C";
    bytes32 internal constant ILK_D = "ILK-D";

    IlkRegistryMockV2 internal registry;
    ClipperMomGlobalMockV2 internal clipperMom;

    event SetBreaker(bytes32 indexed ilk, address indexed clip);

    function setUp() public {
        registry = new IlkRegistryMockV2();
        clipperMom = new ClipperMomGlobalMockV2();
        MalformedGlobalTargetV2 pause = new MalformedGlobalTargetV2();
        vm.mockCall(CHAINLOG, abi.encodeWithSignature("getAddress(bytes32)", MCD_PAUSE), abi.encode(address(pause)));
    }

    function testMetadata() public {
        GlobalClipBreakerSpellV2 spell = _deploy();

        assertEq(spell.description(), "Emergency Spell | Global Clip Breaker");
        assertEq(spell.ilkRegistry(), address(registry));
        assertEq(spell.clipperMom(), address(clipperMom));
        assertEq(spell.BREAKER_LEVEL(), 3);
        assertEq(spell.BREAKER_DELAY(), 0);
    }

    function testCoversExistingAndLaterEnrollment() public {
        ClipGlobalMockV2 clipA = new ClipGlobalMockV2();
        _addClip(ILK_A, address(clipA));
        GlobalClipBreakerSpellV2 spell = _deploy();

        assertFalse(spell.done());
        vm.expectEmit(true, true, false, true, address(spell));
        emit SetBreaker(ILK_A, address(clipA));
        spell.schedule();
        assertEq(clipA.stopped(), 3);
        assertTrue(spell.done());

        ClipGlobalMockV2 clipB = new ClipGlobalMockV2();
        _addClip(ILK_B, address(clipB));
        assertFalse(spell.done());
        vm.expectEmit(true, true, false, true, address(spell));
        emit SetBreaker(ILK_B, address(clipB));
        spell.schedule();
        assertEq(clipB.stopped(), 3);
        assertTrue(spell.done());

        spell.schedule();
        assertTrue(spell.done());
    }

    function testSkipsZeroXlipEntries() public {
        registry.add(ILK_A);
        GlobalClipBreakerSpellV2 spell = _deploy();

        assertTrue(spell.done());
        spell.schedule();
        assertTrue(spell.done());
    }

    function testEmptyRegistryFullCallIsNoOpAndRangeReverts() public {
        GlobalClipBreakerSpellV2 spell = _deploy();

        assertTrue(spell.done());
        spell.schedule();
        assertTrue(spell.done());

        vm.expectRevert("GlobalClipBreakerSpellV2/empty-registry");
        spell.scheduleRange(0, 0);
    }

    function testRangeIsInclusiveAndCapsEnd() public {
        ClipGlobalMockV2 clipA = new ClipGlobalMockV2();
        ClipGlobalMockV2 clipB = new ClipGlobalMockV2();
        ClipGlobalMockV2 clipC = new ClipGlobalMockV2();
        ClipGlobalMockV2 clipD = new ClipGlobalMockV2();
        _addClip(ILK_A, address(clipA));
        _addClip(ILK_B, address(clipB));
        _addClip(ILK_C, address(clipC));
        _addClip(ILK_D, address(clipD));
        GlobalClipBreakerSpellV2 spell = _deploy();

        spell.scheduleRange(1, 2);
        assertEq(clipA.stopped(), 0);
        assertEq(clipB.stopped(), 3);
        assertEq(clipC.stopped(), 3);
        assertEq(clipD.stopped(), 0);

        spell.scheduleRange(3, type(uint256).max);
        assertEq(clipD.stopped(), 3);
        assertFalse(spell.done());

        spell.scheduleRange(0, 0);
        assertTrue(spell.done());
    }

    function testRangeRejectsInvalidBounds() public {
        _addClip(ILK_A, address(new ClipGlobalMockV2()));
        _addClip(ILK_B, address(new ClipGlobalMockV2()));
        GlobalClipBreakerSpellV2 spell = _deploy();

        vm.expectRevert("GlobalClipBreakerSpellV2/start-out-of-bounds");
        spell.scheduleRange(2, 2);
        vm.expectRevert("GlobalClipBreakerSpellV2/invalid-range");
        spell.scheduleRange(1, 0);
    }

    function testMalformedCoveredTargetReverts() public {
        MalformedGlobalTargetV2 malformed = new MalformedGlobalTargetV2();
        _addClip(ILK_A, address(malformed));
        GlobalClipBreakerSpellV2 spell = _deploy();

        vm.expectRevert();
        spell.done();
        vm.expectRevert();
        spell.schedule();
    }

    function testFullAndRangeCallsRollbackAtomically() public {
        ClipGlobalMockV2 clipA = new ClipGlobalMockV2();
        RevertingClipGlobalMockV2 clipB = new RevertingClipGlobalMockV2();
        _addClip(ILK_A, address(clipA));
        _addClip(ILK_B, address(clipB));
        GlobalClipBreakerSpellV2 spell = _deploy();

        vm.expectRevert("RevertingClipGlobalMockV2/set-failed");
        spell.schedule();
        assertEq(clipA.stopped(), 0);

        vm.expectRevert("RevertingClipGlobalMockV2/set-failed");
        spell.scheduleRange(0, 1);
        assertEq(clipA.stopped(), 0);
    }

    function testPostconditionFailureRollsBackEarlierTargets() public {
        ClipGlobalMockV2 clipA = new ClipGlobalMockV2();
        PermissiveClipGlobalMockV2 clipB = new PermissiveClipGlobalMockV2();
        _addClip(ILK_A, address(clipA));
        _addClip(ILK_B, address(clipB));
        GlobalClipBreakerSpellV2 spell = _deploy();

        vm.expectRevert("GlobalClipBreakerSpellV2/not-stopped");
        spell.schedule();

        assertEq(clipA.stopped(), 0);
        assertEq(clipB.stopped(), 0);
    }

    function testUnauthorizedExecutionRevertsWithoutPartialEffects() public {
        ClipGlobalMockV2 clipA = new ClipGlobalMockV2();
        ClipGlobalMockV2 clipB = new ClipGlobalMockV2();
        _addClip(ILK_A, address(clipA));
        _addClip(ILK_B, address(clipB));
        GlobalClipBreakerSpellV2 spell = new GlobalClipBreakerSpellV2(address(registry), address(clipperMom));

        vm.expectRevert("ClipperMomGlobalMockV2/not-authorized");
        spell.schedule();
        assertEq(clipA.stopped(), 0);
        assertEq(clipB.stopped(), 0);
    }

    function _deploy() internal returns (GlobalClipBreakerSpellV2 spell) {
        spell = new GlobalClipBreakerSpellV2(address(registry), address(clipperMom));
        clipperMom.rely(address(spell));
    }

    function _addClip(bytes32 ilk, address clip) internal {
        registry.add(ilk);
        registry.setXlip(ilk, clip);
    }
}
