// SPDX-FileCopyrightText: © 2024 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.
pragma solidity ^0.8.16;

import {stdStorage, StdStorage} from "forge-std/Test.sol";
import {DssTest, DssInstance, MCD} from "dss-test/DssTest.sol";
import {DssEmergencySpellLike} from "../DssEmergencySpell.sol";
import {GroupedClipBreakerSpell, GroupedClipBreakerFactory} from "./GroupedClipBreakerSpell.sol";

interface IlkRegistryLike {
    function xlip(bytes32 ilk) external view returns (address);
    function file(bytes32 ilk, bytes32 what, address data) external;
}

interface ClipperMomLike {
    function setBreaker(address clip, uint256 level, uint256 delay) external;
}

interface ClipLike {
    function stopped() external view returns (uint256);
    function wards(address who) external view returns (uint256);
    function deny(address who) external;
}

abstract contract GroupedClipBreakerSpellTest is DssTest {
    using stdStorage for StdStorage;

    address constant CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;
    DssInstance dss;
    address pauseProxy;
    address chief;
    IlkRegistryLike ilkReg;
    ClipperMomLike clipperMom;
    bytes32[] ilks;
    ClipLike clipA;
    ClipLike clipB;
    ClipLike clipC;
    GroupedClipBreakerFactory factory;
    DssEmergencySpellLike spell;

    function setUp() public {
        vm.createSelectFork("mainnet");

        dss = MCD.loadFromChainlog(CHAINLOG);
        MCD.giveAdminAccess(dss);
        pauseProxy = dss.chainlog.getAddress("MCD_PAUSE_PROXY");
        chief = dss.chainlog.getAddress("MCD_ADM");
        ilkReg = IlkRegistryLike(dss.chainlog.getAddress("ILK_REGISTRY"));
        clipperMom = ClipperMomLike(dss.chainlog.getAddress("CLIPPER_MOM"));
        _setUpSub();
        factory = new GroupedClipBreakerFactory();
        spell = DssEmergencySpellLike(factory.deploy(ilks));

        stdstore.target(chief).sig("hat()").checked_write(address(spell));

        vm.makePersistent(chief);
    }

    function _setUpSub() internal virtual;

    function testClipBreakerOnSchedule() public {
        assertEq(clipA.stopped(), 0, "ClipA: before: clip already stopped");
        assertFalse(spell.done(), "ClipA: before: spell already done");
        assertEq(clipB.stopped(), 0, "ClipB: before: clip already stopped");
        assertFalse(spell.done(), "ClipB: before: spell already done");
        if (ilks.length > 2) {
            assertEq(clipC.stopped(), 0, "ClipC: before: clip already stopped");
        }
        assertFalse(spell.done(), "ClipC: before: spell already done");

        vm.expectEmit(true, true, true, true);
        emit SetBreaker(ilks[0], address(clipA));
        vm.expectEmit(true, true, true, true);
        emit SetBreaker(ilks[1], address(clipB));
        if (ilks.length > 2) {
            vm.expectEmit(true, true, true, true);
            emit SetBreaker(ilks[2], address(clipC));
        }
        spell.schedule();

        assertEq(clipA.stopped(), 3, "ClipA: after: clip not stopped");
        assertTrue(spell.done(), "ClipA: after: spell not done");
        assertEq(clipB.stopped(), 3, "ClipB: after: clip not stopped");
        assertTrue(spell.done(), "ClipB: after: spell not done");
        if (ilks.length > 2) {
            assertEq(clipC.stopped(), 3, "ClipC: after: clip not stopped");
            assertTrue(spell.done(), "ClipC: after: spell not done");
        }
    }

    function testDoneWhenClipIsNotSetInIlkReg() public {
        vm.startPrank(pauseProxy);
        ilkReg.file(ilks[0], "xlip", address(0));
        ilkReg.file(ilks[1], "xlip", address(0));
        if (ilks.length > 2) {
            ilkReg.file(ilks[2], "xlip", address(0));
        }
        vm.stopPrank();

        assertTrue(spell.done(), "spell not done");
    }

    function testDoneWhenClipperMomIsNotWardInClip() public {
        uint256 before = vm.snapshotState();

        vm.prank(pauseProxy);
        clipA.deny(address(clipperMom));
        assertFalse(spell.done(), "ClipA: spell already done");
        vm.revertToState(before);

        vm.prank(pauseProxy);
        clipB.deny(address(clipperMom));
        assertFalse(spell.done(), "ClipB: spell already done");
        vm.revertToState(before);

        if (ilks.length > 2) {
            vm.prank(pauseProxy);
            clipC.deny(address(clipperMom));
            assertFalse(spell.done(), "ClipC: spell already done");
            vm.revertToState(before);
        }

        vm.startPrank(pauseProxy);
        clipA.deny(address(clipperMom));
        clipB.deny(address(clipperMom));
        if (ilks.length > 2) {
            clipC.deny(address(clipperMom));
        }
        vm.stopPrank();
        assertTrue(spell.done(), "after: spell not done");
    }

    function testRevertClipBreakerWhenItDoesNotHaveTheHat() public {
        stdstore.target(chief).sig("hat()").checked_write(address(0));

        vm.expectRevert();
        spell.schedule();
    }

    function testDoneWhenClipWardReverts() public {
        vm.mockCallRevert(
            address(clipA), abi.encodeWithSelector(ClipLike.wards.selector, address(clipperMom)), bytes("revert")
        );
        assertFalse(spell.done(), "ClipA: spell done unexpectedly");

        vm.mockCallRevert(
            address(clipB), abi.encodeWithSelector(ClipLike.wards.selector, address(clipperMom)), bytes("revert")
        );

        if (ilks.length > 2) {
            assertFalse(spell.done(), "ClipB: spell done unexpectedly");
            vm.mockCallRevert(
                address(clipC), abi.encodeWithSelector(ClipLike.wards.selector, address(clipperMom)), bytes("revert")
            );
        }

        assertTrue(spell.done(), "spell not done");
    }

    function testDoneWhenClipStoppedReverts() public {
        vm.mockCallRevert(address(clipA), abi.encodeWithSelector(ClipLike.stopped.selector), bytes("revert"));
        assertFalse(spell.done(), "ClipA: spell done unexpectedly");

        vm.mockCallRevert(address(clipB), abi.encodeWithSelector(ClipLike.stopped.selector), bytes("revert"));

        if (ilks.length > 2) {
            assertFalse(spell.done(), "ClipB: spell done unexpectedly");
            vm.mockCallRevert(address(clipC), abi.encodeWithSelector(ClipLike.stopped.selector), bytes("revert"));
        }

        assertTrue(spell.done(), "spell not done");
    }

    event SetBreaker(bytes32 indexed ilk, address indexed clip);
}

contract EthGroupedClipBreakerSpellTest is GroupedClipBreakerSpellTest {
    function _setUpSub() internal override {
        clipA = ClipLike(ilkReg.xlip("ETH-A"));
        clipB = ClipLike(ilkReg.xlip("ETH-B"));
        clipC = ClipLike(ilkReg.xlip("ETH-C"));
        ilks = new bytes32[](3);
        ilks[0] = "ETH-A";
        ilks[1] = "ETH-B";
        ilks[2] = "ETH-C";
    }

    function testDescription() public view {
        assertEq(spell.description(), "Emergency Spell | Grouped Clip Breaker: ETH-A, ETH-B, ETH-C");
    }
}

contract WstethGroupedClipBreakerSpellTest is GroupedClipBreakerSpellTest {
    function _setUpSub() internal override {
        clipA = ClipLike(ilkReg.xlip("WSTETH-A"));
        clipB = ClipLike(ilkReg.xlip("WSTETH-B"));
        ilks = new bytes32[](2);
        ilks[0] = "WSTETH-A";
        ilks[1] = "WSTETH-B";
    }

    function testDescription() public view {
        assertEq(spell.description(), "Emergency Spell | Grouped Clip Breaker: WSTETH-A, WSTETH-B");
    }
}

contract WbtcGroupedClipBreakerSpellTest is GroupedClipBreakerSpellTest {
    function _setUpSub() internal override {
        clipA = ClipLike(ilkReg.xlip("WBTC-A"));
        clipB = ClipLike(ilkReg.xlip("WBTC-B"));
        clipC = ClipLike(ilkReg.xlip("WBTC-C"));
        ilks = new bytes32[](3);
        ilks[0] = "WBTC-A";
        ilks[1] = "WBTC-B";
        ilks[2] = "WBTC-C";
    }

    function testDescription() public view {
        assertEq(spell.description(), "Emergency Spell | Grouped Clip Breaker: WBTC-A, WBTC-B, WBTC-C");
    }
}
