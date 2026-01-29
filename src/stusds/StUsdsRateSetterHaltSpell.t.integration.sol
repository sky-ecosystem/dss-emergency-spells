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
import {StUsdsRateSetterHaltSpell} from "./StUsdsRateSetterHaltSpell.sol";

interface StUsdsRateSetterLike {
    function bad() external view returns (uint8);
    function deny(address usr) external;
    function wards(address) external view returns (uint256);
    function file(bytes32 what, uint256 data) external;
}

interface StUsdsLike {
    function deny(address) external;
    function wards(address) external view returns (uint256);
}

contract StUsdsRateSetterHaltSpellTest is DssTest {
    using stdStorage for StdStorage;

    address constant CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;
    address chief;
    address stUsdsMom;
    address pauseProxy;

    DssInstance dss;
    StUsdsRateSetterHaltSpell spell;
    StUsdsLike stUsds;
    StUsdsRateSetterLike stUsdsRateSetter;

    function setUp() public {
        vm.createSelectFork("mainnet");

        dss = MCD.loadFromChainlog(CHAINLOG);
        MCD.giveAdminAccess(dss);
        chief = dss.chainlog.getAddress("MCD_ADM");
        stUsds = StUsdsLike(dss.chainlog.getAddress("STUSDS"));
        stUsdsMom = dss.chainlog.getAddress("STUSDS_MOM");
        stUsdsRateSetter = StUsdsRateSetterLike(dss.chainlog.getAddress("STUSDS_RATE_SETTER"));
        pauseProxy = dss.chainlog.getAddress("MCD_PAUSE_PROXY");

        spell = new StUsdsRateSetterHaltSpell();

        stdstore.target(chief).sig("hat()").checked_write(address(spell));

        vm.prank(pauseProxy);
        stUsdsRateSetter.file("bad", 0);

        vm.makePersistent(chief);
    }

    function testHaltRateOnSchedule() public {
        uint8 pBad = stUsdsRateSetter.bad();
        assertEq(pBad, 0, "before: stUsdsRateSetter bad already set");

        vm.expectEmit(true, true, true, false);
        emit HaltRateSetter(address(stUsdsRateSetter));
        spell.schedule();

        uint8 bad = stUsdsRateSetter.bad();
        assertEq(bad, 1, "after: stUsdsRateSetter bad not set");
        assertTrue(spell.done(), "after: spell not done");
    }

    function testDescription() public view {
        assertEq(spell.description(), "Emergency Spell | stUSDS | Halt Rate Setter");
    }

    function testRevertHaltRateWhenItDoesNotHaveTheHat() public {
        stdstore.target(chief).sig("hat()").checked_write(address(0));

        uint8 pBad = stUsdsRateSetter.bad();
        assertEq(pBad, 0, "before: stUsdsRateSetter bad already set");
        assertFalse(spell.done(), "before: spell already done");

        vm.expectRevert();
        spell.schedule();

        uint8 bad = stUsdsRateSetter.bad();
        assertEq(bad, 0, "after: stUsdsRateSetter bad set unexpectedly");
        assertFalse(spell.done(), "after: spell done unexpectedly");
    }

    function testDoneWhenStUsdsMomIsNotWardInStUsds() public {
        vm.prank(pauseProxy);
        stUsds.deny(stUsdsMom);

        assertTrue(spell.done(), "spell not done");
    }

    function testDoneWhenStUsdsRateSetterIsNotWardInStUsds() public {
        vm.prank(pauseProxy);
        stUsds.deny(address(stUsdsRateSetter));

        assertTrue(spell.done(), "spell not done");
    }

    function testDoneWhenStUsdsMomIsNotWardInStUsdsRateSetter() public {
        vm.prank(pauseProxy);
        stUsdsRateSetter.deny(stUsdsMom);

        assertTrue(spell.done(), "spell not done");
    }

    function testDoneWhenStUsdsToRateSetterWardReverts() public {
        // Mock stUsds.wards(stUsdsRateSetter) to revert
        vm.mockCallRevert(
            address(spell.stUsds()),
            abi.encodeWithSelector(StUsdsLike.wards.selector, address(spell.stUsdsRateSetter())),
            "revert"
        );

        assertTrue(spell.done(), "spell not done");
    }

    function testDoneWhenStUsdsToMomWardReverts() public {
        // Mock stUsds.wards(stUsdsMom) to revert
        vm.mockCallRevert(
            address(spell.stUsds()),
            abi.encodeWithSelector(StUsdsLike.wards.selector, address(spell.stUsdsMom())),
            "revert"
        );

        assertTrue(spell.done(), "spell not done");
    }

    function testDoneWhenRateSetterToMomWardReverts() public {
        // Mock stUsdsRateSetter.wards() to revert
        vm.mockCallRevert(
            address(spell.stUsdsRateSetter()),
            abi.encodeWithSelector(StUsdsRateSetterLike.wards.selector, address(spell.stUsdsMom())),
            "revert"
        );

        assertTrue(spell.done(), "spell not done");
    }

    function testDoneWhenRateSetterBadReverts() public {
        // Mock stUsdsRateSetter.bad() to revert
        vm.mockCallRevert(
            address(spell.stUsdsRateSetter()), abi.encodeWithSelector(StUsdsRateSetterLike.bad.selector), "revert"
        );

        assertTrue(spell.done(), "spell not done");
    }

    event HaltRateSetter(address indexed rateSetter);
}
