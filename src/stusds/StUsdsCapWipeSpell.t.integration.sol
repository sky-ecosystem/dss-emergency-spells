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
import {StUsdsCapWipeSpell} from "./StUsdsCapWipeSpell.sol";

interface StUsdsMomLike {
}

interface StUsdsRateSetterLike {
    function deny(address usr) external;
    function maxCap() external view returns (uint256);
}

interface StUsdsLike {
    function cap() external view returns (uint256);
    function deny(address) external;
}

contract StUsdsCapWipeSpellTest is DssTest {
    using stdStorage for StdStorage;

    address constant CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;
    DssInstance dss;
    address chief;
    StUsdsMomLike stUsdsMom;
    StUsdsLike stUsds;
    StUsdsRateSetterLike stUsdsRateSetter;
    StUsdsCapWipeSpell spell;

    function setUp() public {
        vm.createSelectFork("mainnet");

        dss = MCD.loadFromChainlog(CHAINLOG);
        MCD.giveAdminAccess(dss);
        chief = dss.chainlog.getAddress("MCD_ADM");
        stUsdsMom = StUsdsMomLike(dss.chainlog.getAddress("STUSDS_MOM"));
        stUsds = StUsdsLike(dss.chainlog.getAddress("STUSDS"));
        stUsdsRateSetter = StUsdsRateSetterLike(dss.chainlog.getAddress("STUSDS_RATE_SETTER"));
        spell = new StUsdsCapWipeSpell();

        stdstore.target(chief).sig("hat()").checked_write(address(spell));

        vm.makePersistent(chief);
    }

    function testCapWipeOnSchedule() public {
        uint256 pCap = stUsds.cap();
        assertGt(pCap, 0, "before: stUsds cap already wiped");
        uint256 pMaxCap = stUsdsRateSetter.maxCap();
        assertGt(pMaxCap, 0, "before: stUsdsRateSetter maxCap already wiped");

        vm.expectEmit(true, true, true, false);
        emit ZeroCap(address(stUsdsRateSetter));
        spell.schedule();

        uint256 cap = stUsds.cap();
        assertEq(cap, 0, "after: stUsds line already wiped");
        uint256 maxCap = stUsdsRateSetter.maxCap();
        assertEq(maxCap, 0, "after: stUsdsRateSetter maxCap already wiped");
        assertTrue(spell.done(), "after: spell not done");
    }

    function testRevertCapWipeWhenItDoesNotHaveTheHat() public {
        stdstore.target(chief).sig("hat()").checked_write(address(0));

         uint256 pCap = stUsds.cap();
        assertGt(pCap, 0, "before: stUsds cap already wiped");
        uint256 pMaxCap = stUsdsRateSetter.maxCap();
        assertGt(pMaxCap, 0, "before: stUsdsRateSetter maxCap already wiped");
        assertFalse(spell.done(), "before: spell already done");

        vm.expectRevert();
        spell.schedule();

        uint256 cap = stUsds.cap();
        assertGt(cap, 0, "after: cap wiped unexpectedly");
        uint256 maxCap = stUsdsRateSetter.maxCap();
        assertGt(maxCap, 0, "after: maxCap wiped unexpectedly");
        assertFalse(spell.done(), "after: spell done unexpectedly");
    }

    function testDoneWhenStUsdsMomIsNotWardInStUsds() public {
        address pauseProxy = dss.chainlog.getAddress("MCD_PAUSE_PROXY");
        vm.prank(pauseProxy);
        stUsds.deny(address(stUsdsMom));

        assertTrue(spell.done(), "spell not done");
    }

    function testDoneWhenStUsdsRateSetterIsNotWardInStUsds() public {
        address pauseProxy = dss.chainlog.getAddress("MCD_PAUSE_PROXY");
        vm.prank(pauseProxy);
        stUsds.deny(address(stUsdsRateSetter));

        assertTrue(spell.done(), "spell not done");
    }

    function testDoneWhenStUsdsMomIsNotWardInStUsdsRateSetter() public {
        address pauseProxy = dss.chainlog.getAddress("MCD_PAUSE_PROXY");
        vm.prank(pauseProxy);
        stUsdsRateSetter.deny(address(stUsdsMom));

        assertTrue(spell.done(), "spell not done");
    }

    event ZeroCap(address indexed rateSetter);
}
