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
import {StUsdsRateSetterDissBudSpell, StUsdsRateSetterDissBudFactory} from "./StUsdsRateSetterDissBudSpell.sol";

interface StUsdsRateSetterLike {
    function buds(address) external view returns (uint256);
    function deny(address usr) external;
    function wards(address) external view returns (uint256);
}

interface StUsdsLike {
    function deny(address) external;
    function wards(address) external view returns (uint256);
}

contract StUsdsRateSetterDissBudSpellTest is DssTest {
    using stdStorage for StdStorage;

    address constant CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;
    address chief;
    address stUsdsMom;
    address bud;
    DssInstance dss;
    DssEmergencySpellLike spell;
    StUsdsRateSetterLike stUsdsRateSetter;
    StUsdsRateSetterDissBudFactory factory;
    StUsdsLike stUsds;

    function setUp() public {
        vm.createSelectFork("mainnet");

        dss = MCD.loadFromChainlog(CHAINLOG);
        MCD.giveAdminAccess(dss);
        chief = dss.chainlog.getAddress("MCD_ADM");
        stUsds = StUsdsLike(dss.chainlog.getAddress("STUSDS"));
        stUsdsMom = dss.chainlog.getAddress("STUSDS_MOM");
        stUsdsRateSetter = StUsdsRateSetterLike(dss.chainlog.getAddress("STUSDS_RATE_SETTER"));

        bud = makeAddr("bud");
        // Add bud to rate setter
        stdstore.target(address(stUsdsRateSetter)).sig("buds(address)").with_key(bud).checked_write(uint256(1));

        factory = new StUsdsRateSetterDissBudFactory();

        spell = DssEmergencySpellLike(factory.deploy(bud));

        stdstore.target(chief).sig("hat()").checked_write(address(spell));

        vm.makePersistent(chief);
    }

    function testDissRateSetterOnSchedule() public {
        uint256 pBud = stUsdsRateSetter.buds(bud);
        assertEq(pBud, 1, "before: stUsdsRateSetter bud already dissed");

        vm.expectEmit(true, true, true, false);
        emit DissRateSetterBud(address(stUsdsRateSetter), bud);
        spell.schedule();

        uint256 aBud = stUsdsRateSetter.buds(bud);
        assertEq(aBud, 0, "after: stUsdsRateSetter bud not dissed");
        assertTrue(spell.done(), "after: spell not done");
    }

    function testDescription() public view {
        assertEq(spell.description(), "Emergency Spell | stUSDS | Diss Rate Setter Bud");
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

    // Revert wards

    function testDoneWhenStUsdsToRateSetterWardReverts() public {
        StUsdsRateSetterDissBudSpell spellRevert = StUsdsRateSetterDissBudSpell(factory.deploy(bud));
        // Mock stUsds.wards(stUsdsRateSetter) to revert
        vm.mockCallRevert(
            address(spellRevert.stUsds()),
            abi.encodeWithSelector(StUsdsLike.wards.selector, address(spellRevert.stUsdsRateSetter())),
            "revert"
        );

        assertTrue(spellRevert.done(), "spell not done");
    }

    function testDoneWhenStUsdsToMomWardReverts() public {
        StUsdsRateSetterDissBudSpell spellRevert = StUsdsRateSetterDissBudSpell(factory.deploy(bud));
        // Mock stUsds.wards(stUsdsMom) to revert
        vm.mockCallRevert(
            address(spellRevert.stUsds()),
            abi.encodeWithSelector(StUsdsLike.wards.selector, address(spellRevert.stUsdsMom())),
            "revert"
        );

        assertTrue(spellRevert.done(), "spell not done");
    }

    function testDoneWhenRateSetterToMomWardReverts() public {
        StUsdsRateSetterDissBudSpell spellRevert = StUsdsRateSetterDissBudSpell(factory.deploy(bud));
        // Mock stUsdsRateSetter.wards() to revert
        vm.mockCallRevert(
            address(spellRevert.stUsdsRateSetter()),
            abi.encodeWithSelector(StUsdsRateSetterLike.wards.selector, address(spellRevert.stUsdsMom())),
            "revert"
        );

        assertTrue(spellRevert.done(), "spell not done");
    }

    // Revert buds

    function testDoneWhenRateSetterBudsReverts() public {
        StUsdsRateSetterDissBudSpell spellRevert = StUsdsRateSetterDissBudSpell(factory.deploy(bud));
        // Mock stUsdsRateSetter.wards() to revert
        vm.mockCallRevert(
            address(spellRevert.stUsdsRateSetter()),
            abi.encodeWithSelector(StUsdsRateSetterLike.buds.selector, address(bud)),
            "revert"
        );

        assertTrue(spellRevert.done(), "spell not done");
    }

    event DissRateSetterBud(address indexed rateSetter, address bud);
}
