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
import {StUsdsDissRateSetterBudSpell,StUsdsDissRateSetterBudFactory} from "./StUsdsDissRateSetterBudSpell.sol";

interface StUsdsRateSetterLike {
    function buds(address) external view returns (uint256);
    function deny(address usr) external;
}

interface StUsdsLike {
    function deny(address) external;
}


contract StUsdsDissBudSpellTest is DssTest {
    using stdStorage for StdStorage;

    address constant CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;
    DssInstance dss;
    address chief;
    StUsdsRateSetterLike stUsdsRateSetter;
    StUsdsDissRateSetterBudFactory factory;
    StUsdsLike stUsds;
    address stUsdsMom;
    DssEmergencySpellLike spell;
    address bud = 0xBB865F94B8A92E57f79fCc89Dfd4dcf0D3fDEA16;

    function setUp() public {
        vm.createSelectFork("mainnet");

        dss = MCD.loadFromChainlog(CHAINLOG);
        MCD.giveAdminAccess(dss);
        chief = dss.chainlog.getAddress("MCD_ADM");
        stUsdsRateSetter = StUsdsRateSetterLike(dss.chainlog.getAddress("STUSDS_RATE_SETTER"));
        stUsds = StUsdsLike(dss.chainlog.getAddress("STUSDS"));
        stUsdsMom = dss.chainlog.getAddress("STUSDS_MOM");

        factory = new StUsdsDissRateSetterBudFactory();
        spell = DssEmergencySpellLike(factory.deploy(bud));

        stdstore.target(chief).sig("hat()").checked_write(address(spell));

        vm.makePersistent(chief);
    }

    function testDissRateSetterOnSchedule() public {
        uint256 pBud = stUsdsRateSetter.buds(bud);
        assertEq(pBud, 1, "before: stUsdsRateSetter bud already dissed");

        vm.expectEmit(true, true, true, false);
        emit DissRateSetterBud(address(stUsdsRateSetter),bud);
        spell.schedule();

        uint256 aBud = stUsdsRateSetter.buds(bud);
        assertEq(aBud, 0, "after: stUsdsRateSetter bud not dissed");
        assertTrue(spell.done(), "after: spell not done");
    }

    function testRevertDissRateSetterWhenItDoesNotHaveTheHat() public {
        stdstore.target(chief).sig("hat()").checked_write(address(0));

        uint256 pBud = stUsdsRateSetter.buds(bud);
        assertEq(pBud, 1, "before: stUsdsRateSetter bud already dissed");

        assertFalse(spell.done(), "before: spell already done");

        vm.expectRevert();
        spell.schedule();

        uint256 aBud = stUsdsRateSetter.buds(bud);
        assertEq(aBud, 1, "after: stUsdsRateSetter bud dissed unexpectedly");
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
    
    event DissRateSetterBud(address indexed rateSetter, address bud);
}
