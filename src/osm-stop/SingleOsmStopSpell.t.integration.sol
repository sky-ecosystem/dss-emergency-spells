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
import {SingleOsmStopFactory, SingleOsmStopSpell} from "./SingleOsmStopSpell.sol";

interface OsmMomLike {
    function osms(bytes32 ilk) external view returns (address);
    function setOsm(bytes32 ilk, address osm) external;
}

interface OsmLike {
    function deny(address who) external;
    function stopped() external view returns (uint256);
    function wards(address) external view returns (uint256);
}

contract SingleOsmStopSpellTest is DssTest {
    using stdStorage for StdStorage;

    address constant CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;
    DssInstance dss;
    address chief;
    bytes32 ilk = "ETH-A";
    OsmMomLike osmMom;
    OsmLike osm;
    SingleOsmStopFactory factory;
    SingleOsmStopSpell spell;

    function setUp() public {
        vm.createSelectFork("mainnet");

        dss = MCD.loadFromChainlog(CHAINLOG);
        MCD.giveAdminAccess(dss);
        chief = dss.chainlog.getAddress("MCD_ADM");
        osmMom = OsmMomLike(dss.chainlog.getAddress("OSM_MOM"));
        osm = OsmLike(osmMom.osms(ilk));
        factory = new SingleOsmStopFactory();
        spell = SingleOsmStopSpell(factory.deploy(ilk));

        stdstore.target(chief).sig("hat()").checked_write(address(spell));

        vm.makePersistent(chief);
    }

    function testOsmStopOnSchedule() public {
        assertEq(osm.stopped(), 0, "before: oracle already frozen");
        assertFalse(spell.done(), "before: spell already done");

        vm.expectEmit(true, true, true, true);
        emit Stop(address(osm));
        spell.schedule();

        assertEq(osm.stopped(), 1, "after: oracle not frozen");
        assertTrue(spell.done(), "after: spell not done");
    }

    function testDoneWhenOsmIsNotAddedToOsmMom() public {
        address pauseProxy = dss.chainlog.getAddress("MCD_PAUSE_PROXY");
        vm.startPrank(pauseProxy);
        osmMom.setOsm(ilk, address(0));

        assertTrue(spell.done(), "spell not done");
    }

    function testDoneWhenOsmMomIsNotWardOnOsm() public {
        address pauseProxy = dss.chainlog.getAddress("MCD_PAUSE_PROXY");
        vm.prank(pauseProxy);
        osm.deny(address(osmMom));

        assertTrue(spell.done(), "spell not done");
    }

    function testRevertOsmStopWhenItDoesNotHaveTheHat() public {
        stdstore.target(chief).sig("hat()").checked_write(address(0));

        assertEq(osm.stopped(), 0, "before: oracle already frozen");
        assertFalse(spell.done(), "before: spell already done");

        vm.expectRevert();
        spell.schedule();

        assertEq(osm.stopped(), 0, "after: oracle frozen unexpectedly");
        assertFalse(spell.done(), "after: spell done unexpectedly");
    }

    function testDescription() public view {
        assertEq(spell.description(), string(abi.encodePacked("Emergency Spell | OSM Stop: ", ilk)));
    }

    function testDoneWhenOsmWardReverts() public {
        // Mock osm.wards(osmMom) to revert
        vm.mockCallRevert(
            address(spell.osmMom().osms(spell.ilk())),
            abi.encodeWithSelector(OsmLike.wards.selector, address(spell.osmMom())),
            "revert"
        );

        assertTrue(spell.done(), "spell not done");
    }

    function testDoneWhenOsmStoppedReverts() public {
        // Mock osm.stopped() to revert
        vm.mockCallRevert(
            address(spell.osmMom().osms(spell.ilk())), abi.encodeWithSelector(OsmLike.stopped.selector), "revert"
        );

        assertTrue(spell.done(), "spell not done");
    }

    event Stop(address indexed osm);
}
