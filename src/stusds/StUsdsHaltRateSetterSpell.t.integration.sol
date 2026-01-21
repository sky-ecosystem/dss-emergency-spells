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
import {StUsdsHaltRateSetterSpell} from "./StUsdsHaltRateSetterSpell.sol";

interface StUsdsRateSetterLike {
    function bad() external view returns (uint8);
    function deny(address usr) external;
}

interface StUsdsLike {
    function deny(address) external;
}


contract StUsdsLineWipeSpellTest is DssTest {
    using stdStorage for StdStorage;

    address constant CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;
    DssInstance dss;
    address chief;
    StUsdsRateSetterLike stUsdsRateSetter;
    StUsdsLike stUsds;
    address stUsdsMom;
    StUsdsHaltRateSetterSpell spell;

    function setUp() public {
        vm.createSelectFork("mainnet");

        dss = MCD.loadFromChainlog(CHAINLOG);
        MCD.giveAdminAccess(dss);
        chief = dss.chainlog.getAddress("MCD_ADM");
        stUsdsRateSetter = StUsdsRateSetterLike(dss.chainlog.getAddress("STUSDS_RATE_SETTER"));
        stUsdsMom = dss.chainlog.getAddress("STUSDS_MOM");
        stUsds = StUsdsLike(dss.chainlog.getAddress("STUSDS"));
        spell = new StUsdsHaltRateSetterSpell();

        stdstore.target(chief).sig("hat()").checked_write(address(spell));

        vm.makePersistent(chief);
    }

    function testHaltRateOnSchedule() public {
        uint256 pBad = stUsdsRateSetter.bad();
        assertEq(pBad, 0, "before: stUsdsRateSetter bad already set");

        vm.expectEmit(true, true, true, false);
        emit HaltRateSetter(address(stUsdsRateSetter));
        spell.schedule();

        uint256 bad = stUsdsRateSetter.bad();
        assertEq(bad, 1, "after: stUsdsRateSetter bad not set");
        assertTrue(spell.done(), "after: spell not done");
    }

    function testRevertHaltRateWhenItDoesNotHaveTheHat() public {
        stdstore.target(chief).sig("hat()").checked_write(address(0));

        uint256 pBad = stUsdsRateSetter.bad();
        assertEq(pBad, 0, "before: stUsdsRateSetter bad already set");
        assertFalse(spell.done(), "before: spell already done");

        vm.expectRevert();
        spell.schedule();

        uint256 bad = stUsdsRateSetter.bad();
        assertEq(bad, 0, "after: stUsdsRateSetter bad set unexpectedly");
        assertFalse(spell.done(), "after: spell done unexpectedly");
    }

    function testDoneWhenStUsdsMomIsNotWardInStUsds() public {
        address pauseProxy = dss.chainlog.getAddress("MCD_PAUSE_PROXY");
        vm.prank(pauseProxy);
        stUsds.deny(stUsdsMom);

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
        stUsdsRateSetter.deny(stUsdsMom);

        assertTrue(spell.done(), "spell not done");
    }
    
    event HaltRateSetter(address indexed rateSetter);
}
