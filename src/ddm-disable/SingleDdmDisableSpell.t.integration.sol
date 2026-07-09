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
import {SingleDdmDisableFactory} from "./SingleDdmDisableSpell.sol";

interface DdmMomLike {
    function disable(address plan) external;
}

interface DdmHubLike {
    function plan(bytes32 ilk) external view returns (address);
    function file(bytes32 ilk, bytes32 what, address data) external;
}

interface DdmPlanLike {
    function active() external view returns (bool);
    function deny(address who) external;
}

contract SingleDdmDisableSpellTest is DssTest {
    using stdStorage for StdStorage;

    address constant CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;
    DssInstance dss;
    address chief;
    bytes32 ilk = "DIRECT-SPARK-DAI";
    DdmMomLike ddmMom;
    DdmHubLike ddmHub;
    DdmPlanLike plan;
    SingleDdmDisableFactory factory;
    DssEmergencySpellLike spell;

    function setUp() public {
        vm.createSelectFork("mainnet");

        dss = MCD.loadFromChainlog(CHAINLOG);
        MCD.giveAdminAccess(dss);
        chief = dss.chainlog.getAddress("MCD_ADM");
        ddmMom = DdmMomLike(dss.chainlog.getAddress("DIRECT_MOM"));
        ddmHub = DdmHubLike(dss.chainlog.getAddress("DIRECT_HUB"));
        plan = DdmPlanLike(ddmHub.plan(ilk));
        factory = new SingleDdmDisableFactory();
        spell = DssEmergencySpellLike(factory.deploy(ilk));

        stdstore.target(chief).sig("hat()").checked_write(address(spell));

        vm.makePersistent(chief);
    }

    function testDdmDisableOnSchedule() public {
        assertTrue(plan.active(), "before: plan already disabled");
        assertFalse(spell.done(), "before: spell already done");

        vm.expectEmit(true, true, true, true);
        emit Disable(address(plan));
        spell.schedule();

        assertFalse(plan.active(), "after: plan not disabled");
        assertTrue(spell.done(), "after: spell not done");
    }

    function testDoneWhenDdmMomIsNotWardOnDdmPlan() public {
        address pauseProxy = dss.chainlog.getAddress("MCD_PAUSE_PROXY");
        vm.prank(pauseProxy);
        plan.deny(address(ddmMom));

        assertTrue(spell.done(), "spell not done");
    }

    function testDoneWhenDdmPlanIsAddressZero() public {
        address pauseProxy = dss.chainlog.getAddress("MCD_PAUSE_PROXY");
        vm.prank(pauseProxy);
        ddmHub.file(ilk, "plan", address(0));

        assertTrue(spell.done(), "spell not done");
    }

    function testRevertDdmDisableWhenItDoesNotHaveTheHat() public {
        stdstore.target(chief).sig("hat()").checked_write(address(0));

        assertTrue(plan.active(), "before: plan already disabled");
        assertFalse(spell.done(), "before: spell already done");

        vm.expectRevert();
        spell.schedule();

        assertTrue(plan.active(), "after: plan disabled unexpectedly");
        assertFalse(spell.done(), "after: spell done unexpectedly");
    }

    function testDescription() public view {
        assertEq(spell.description(), string(abi.encodePacked("Emergency Spell | Disable DDM Plan: ", ilk)));
    }

    event Disable(address indexed plan);
}
