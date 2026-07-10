// SPDX-FileCopyrightText: © 2026 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {Test} from "forge-std/Test.sol";

import {GlobalLineWipeSpellV2} from "../../src/line-wipe/GlobalLineWipeSpellV2.sol";
import {
    AutoLineGlobalMockV2,
    IlkRegistryMockV2,
    LineMomGlobalMockV2,
    MalformedGlobalTargetV2,
    VatGlobalMockV2
} from "../mocks/GlobalSpellMocksV2.sol";

contract GlobalLineWipeSpellV2Test is Test {
    address internal constant CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;
    bytes32 internal constant MCD_PAUSE = "MCD_PAUSE";
    bytes32 internal constant MCD_VAT = "MCD_VAT";
    bytes32 internal constant ILK_A = "ILK-A";
    bytes32 internal constant ILK_B = "ILK-B";
    bytes32 internal constant ILK_C = "ILK-C";
    bytes32 internal constant ILK_D = "ILK-D";

    IlkRegistryMockV2 internal registry;
    VatGlobalMockV2 internal vat;
    AutoLineGlobalMockV2 internal autoLine;
    LineMomGlobalMockV2 internal lineMom;

    event Wipe(bytes32 indexed ilk);

    function setUp() public {
        registry = new IlkRegistryMockV2();
        vat = new VatGlobalMockV2();
        autoLine = new AutoLineGlobalMockV2();
        lineMom = new LineMomGlobalMockV2(address(autoLine), address(vat));
        MalformedGlobalTargetV2 pause = new MalformedGlobalTargetV2();
        vm.mockCall(CHAINLOG, abi.encodeWithSignature("getAddress(bytes32)", MCD_PAUSE), abi.encode(address(pause)));
        vm.mockCall(CHAINLOG, abi.encodeWithSignature("getAddress(bytes32)", MCD_VAT), abi.encode(address(vat)));
    }

    function testMetadata() public {
        GlobalLineWipeSpellV2 spell = _deploy();

        assertEq(spell.description(), "Emergency Spell | Global Line Wipe");
        assertEq(spell.ilkRegistry(), address(registry));
        assertEq(spell.lineMom(), address(lineMom));
        assertEq(spell.autoLine(), address(autoLine));
        assertEq(spell.vat(), address(vat));
    }

    function testCoversExistingAndLaterEnrollment() public {
        _addActive(ILK_A);
        GlobalLineWipeSpellV2 spell = _deploy();

        assertFalse(spell.done());
        vm.expectEmit(true, false, false, true, address(spell));
        emit Wipe(ILK_A);
        spell.schedule();
        assertTrue(spell.done());

        _addActive(ILK_B);
        assertFalse(spell.done());
        vm.expectEmit(true, false, false, true, address(spell));
        emit Wipe(ILK_B);
        spell.schedule();
        assertTrue(spell.done());

        spell.schedule();
        assertTrue(spell.done());
    }

    function testSkipsLineMomUnenrolledIlks() public {
        registry.add(ILK_A);
        autoLine.set(ILK_A);
        vat.setLine(ILK_A, 6);
        GlobalLineWipeSpellV2 spell = _deploy();

        assertTrue(spell.done());
        spell.schedule();

        assertEq(vat.line(ILK_A), 6);
        (uint256 maxLine,,,,) = autoLine.ilks(ILK_A);
        assertEq(maxLine, 1);
    }

    function testEmptyRegistryFullCallIsNoOpAndRangeReverts() public {
        GlobalLineWipeSpellV2 spell = _deploy();

        assertTrue(spell.done());
        spell.schedule();
        assertTrue(spell.done());

        vm.expectRevert("GlobalLineWipeSpellV2/empty-registry");
        spell.scheduleRange(0, 0);
    }

    function testRangeIsInclusiveAndCapsEnd() public {
        _addActive(ILK_A);
        _addActive(ILK_B);
        _addActive(ILK_C);
        _addActive(ILK_D);
        GlobalLineWipeSpellV2 spell = _deploy();

        spell.scheduleRange(1, 2);
        _assertActive(ILK_A);
        _assertWiped(ILK_B);
        _assertWiped(ILK_C);
        _assertActive(ILK_D);

        spell.scheduleRange(3, type(uint256).max);
        _assertWiped(ILK_D);
        assertFalse(spell.done());

        spell.scheduleRange(0, 0);
        assertTrue(spell.done());
    }

    function testRangeRejectsInvalidBounds() public {
        _addActive(ILK_A);
        _addActive(ILK_B);
        GlobalLineWipeSpellV2 spell = _deploy();

        vm.expectRevert("GlobalLineWipeSpellV2/start-out-of-bounds");
        spell.scheduleRange(2, 2);
        vm.expectRevert("GlobalLineWipeSpellV2/invalid-range");
        spell.scheduleRange(1, 0);
    }

    function testMalformedCoveredEntryReverts() public {
        _addActive(ILK_A);
        GlobalLineWipeSpellV2 spell = _deploy();
        autoLine.setRevertOnRead(ILK_A, true);

        vm.expectRevert("AutoLineGlobalMockV2/read-failed");
        spell.done();

        autoLine.setRevertOnRead(ILK_A, false);
        lineMom.setRevertOnWipe(ILK_A, true);
        vm.expectRevert("LineMomGlobalMockV2/wipe-failed");
        spell.schedule();
    }

    function testFullAndRangeCallsRollbackAtomically() public {
        _addActive(ILK_A);
        _addActive(ILK_B);
        GlobalLineWipeSpellV2 spell = _deploy();
        lineMom.setRevertOnWipe(ILK_B, true);

        vm.expectRevert("LineMomGlobalMockV2/wipe-failed");
        spell.schedule();
        _assertActive(ILK_A);

        vm.expectRevert("LineMomGlobalMockV2/wipe-failed");
        spell.scheduleRange(0, 1);
        _assertActive(ILK_A);
    }

    function testUnauthorizedExecutionRevertsWithoutPartialEffects() public {
        _addActive(ILK_A);
        _addActive(ILK_B);
        GlobalLineWipeSpellV2 spell = new GlobalLineWipeSpellV2(address(registry), address(lineMom));

        vm.expectRevert("LineMomGlobalMockV2/not-authorized");
        spell.schedule();
        _assertActive(ILK_A);
        _assertActive(ILK_B);
    }

    function _deploy() internal returns (GlobalLineWipeSpellV2 spell) {
        spell = new GlobalLineWipeSpellV2(address(registry), address(lineMom));
        lineMom.rely(address(spell));
    }

    function _addActive(bytes32 ilk) internal {
        registry.add(ilk);
        lineMom.enroll(ilk);
    }

    function _assertActive(bytes32 ilk) internal view {
        assertEq(lineMom.ilks(ilk), 1);
        assertEq(vat.line(ilk), 6);
        (uint256 maxLine, uint256 gap, uint48 ttl, uint48 last, uint48 lastInc) = autoLine.ilks(ilk);
        assertEq(maxLine, 1);
        assertEq(gap, 2);
        assertEq(ttl, 3);
        assertEq(last, 4);
        assertEq(lastInc, 5);
    }

    function _assertWiped(bytes32 ilk) internal view {
        assertEq(lineMom.ilks(ilk), 0);
        assertEq(vat.line(ilk), 0);
        (uint256 maxLine, uint256 gap, uint48 ttl, uint48 last, uint48 lastInc) = autoLine.ilks(ilk);
        assertEq(maxLine, 0);
        assertEq(gap, 0);
        assertEq(ttl, 0);
        assertEq(last, 0);
        assertEq(lastInc, 0);
    }
}
