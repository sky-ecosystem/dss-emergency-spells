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
import {
    StUsdsSingleLineOrCapWipeSpell,
    StUsdsSingleLineOrCapWipeFactory,
    Flow
} from "./StUsdsSingleLineOrCapWipeSpell.sol";

interface StUsdsRateSetterLike {
    function deny(address usr) external;
    function maxCap() external view returns (uint256);
    function maxLine() external view returns (uint256);
    function wards(address) external view returns (uint256);
}

interface StUsdsLike {
    function cap() external view returns (uint256);
    function deny(address) external;
    function line() external view returns (uint256);
    function wards(address) external view returns (uint256);
}

contract SingleLineOrCapWipeSpellTest is DssTest {
    using stdStorage for StdStorage;

    address constant CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;
    address chief;
    address stUsdsMom;
    DssInstance dss;
    StUsdsLike stUsds;
    StUsdsRateSetterLike stUsdsRateSetter;
    StUsdsSingleLineOrCapWipeFactory factory;

    function setUp() public {
        vm.createSelectFork("mainnet");

        dss = MCD.loadFromChainlog(CHAINLOG);
        MCD.giveAdminAccess(dss);
        chief = dss.chainlog.getAddress("MCD_ADM");
        stUsdsRateSetter = StUsdsRateSetterLike(dss.chainlog.getAddress("STUSDS_RATE_SETTER"));
        stUsds = StUsdsLike(dss.chainlog.getAddress("STUSDS"));
        stUsdsMom = dss.chainlog.getAddress("STUSDS_MOM");
        factory = new StUsdsSingleLineOrCapWipeFactory();
    }

    // WIPE

    function testStUsdsWipeOnScheduleLine() public {
        _checkLineOrCapWipeOnSchedule(Flow.LINE);
    }

    function testStUsdsWipeOnScheduleCap() public {
        _checkLineOrCapWipeOnSchedule(Flow.CAP);
    }

    function testStUsdsWipeOnScheduleBoth() public {
        _checkLineOrCapWipeOnSchedule(Flow.BOTH);
    }

    // MOM is not ward is StUsds

    function testDoneWhenStUsdsMomIsNotWardInStUsdsLine() public {
        _checkDoneWhenStUsdsMomIsNotWardInStUsds(Flow.LINE);
    }

    function testDoneWhenStUsdsMomIsNotWardInStUsdsCap() public {
        _checkDoneWhenStUsdsMomIsNotWardInStUsds(Flow.CAP);
    }

    function testDoneWhenStUsdsMomIsNotWardInStUsdsBoth() public {
        _checkDoneWhenStUsdsMomIsNotWardInStUsds(Flow.BOTH);
    }

    // Rate Setter is not ward is StUsds

    function testDoneWhenStUsdsRateSetterIsNotWardInStUsdsLine() public {
        _checkDoneWhenStUsdsRateSetterIsNotWardInStUsds(Flow.LINE);
    }

    function testDoneWhenStUsdsRateSetterIsNotWardInStUsdsCap() public {
        _checkDoneWhenStUsdsRateSetterIsNotWardInStUsds(Flow.CAP);
    }

    function testDoneWhenStUsdsRateSetterIsNotWardInStUsdsBoth() public {
        _checkDoneWhenStUsdsRateSetterIsNotWardInStUsds(Flow.BOTH);
    }

    // MOM is not ward is Rate Setter

    function testDoneWhenStUsdsMomIsNotWardInStUsdsRateSetterLine() public {
        _checkDoneWhenStUsdsMomIsNotWardInStUsdsRateSetter(Flow.LINE);
    }

    function testDoneWhenStUsdsMomIsNotWardInStUsdsRateSetterCap() public {
        _checkDoneWhenStUsdsMomIsNotWardInStUsdsRateSetter(Flow.CAP);
    }

    function testDoneWhenStUsdsMomIsNotWardInStUsdsRateSetterBoth() public {
        _checkDoneWhenStUsdsMomIsNotWardInStUsdsRateSetter(Flow.BOTH);
    }

    // Revert with no Hat

    function testRevertSpellWhenItDoesNotHaveTheHatLine() public {
        _checkRevertSpellWhenItDoesNotHaveTheHat(Flow.LINE);
    }

    function testRevertSpellWhenItDoesNotHaveTheHatCap() public {
        _checkRevertSpellWhenItDoesNotHaveTheHat(Flow.CAP);
    }

    function testRevertSpellWhenItDoesNotHaveTheHatBoth() public {
        _checkRevertSpellWhenItDoesNotHaveTheHat(Flow.BOTH);
    }

    // Description

    function testDescriptionCap() public {
        _checkDescription(Flow.CAP);
    }

    function testDescriptionLine() public {
        _checkDescription(Flow.LINE);
    }

    function testDescriptionBoth() public {
        _checkDescription(Flow.BOTH);
    }

    // Revert wards

    function testDoneWhenStUsdsToRateSetterWardReverts() public {
        StUsdsSingleLineOrCapWipeSpell spell = StUsdsSingleLineOrCapWipeSpell(factory.deploy(Flow.LINE));
        // Mock stUsds.wards(stUsdsRateSetter) to revert
        vm.mockCallRevert(
            address(spell.stUsds()),
            abi.encodeWithSelector(StUsdsLike.wards.selector, address(spell.stUsdsRateSetter())),
            "revert"
        );

        assertTrue(spell.done(), "spell not done");
    }

    function testDoneWhenStUsdsToMomWardReverts() public {
        StUsdsSingleLineOrCapWipeSpell spell = StUsdsSingleLineOrCapWipeSpell(factory.deploy(Flow.LINE));
        // Mock stUsds.wards(stUsdsMom) to revert
        vm.mockCallRevert(
            address(spell.stUsds()),
            abi.encodeWithSelector(StUsdsLike.wards.selector, address(spell.stUsdsMom())),
            "revert"
        );

        assertTrue(spell.done(), "spell not done");
    }

    function testDoneWhenRateSetterToMomWardReverts() public {
        StUsdsSingleLineOrCapWipeSpell spell = StUsdsSingleLineOrCapWipeSpell(factory.deploy(Flow.LINE));
        // Mock stUsdsRateSetter.wards() to revert
        vm.mockCallRevert(
            address(spell.stUsdsRateSetter()),
            abi.encodeWithSelector(StUsdsRateSetterLike.wards.selector, address(spell.stUsdsMom())),
            "revert"
        );

        assertTrue(spell.done(), "spell not done");
    }

    // HELPERS

    function _checkDescription(Flow flow) internal {
        DssEmergencySpellLike spell = DssEmergencySpellLike(factory.deploy(flow));
        stdstore.target(chief).sig("hat()").checked_write(address(spell));
        string memory description = spell.description();
        if (flow == Flow.LINE) assertEq(description, "Emergency Spell | stUSDS | halt: LINE");
        else if (flow == Flow.CAP) assertEq(description, "Emergency Spell | stUSDS | halt: CAP");
        else assertEq(description, "Emergency Spell | stUSDS | halt: BOTH");
    }

    function _checkLineOrCapWipeOnSchedule(Flow flow) internal {
        DssEmergencySpellLike spell = DssEmergencySpellLike(factory.deploy(flow));
        stdstore.target(chief).sig("hat()").checked_write(address(spell));
        vm.makePersistent(chief);

        uint256 cap = stUsds.cap();
        uint256 line = stUsds.line();
        uint256 maxCap = stUsdsRateSetter.maxCap();
        uint256 maxLine = stUsdsRateSetter.maxLine();

        if (flow == Flow.LINE || flow == Flow.BOTH) {
            assertNotEq(line, 0, "before: STUSDS line already zeroed");
            assertNotEq(maxLine, 0, "before: STUSDS_RATE_SETTER maxLine already zeroed");
        }
        if (flow == Flow.CAP || flow == Flow.BOTH) {
            assertNotEq(cap, 0, "before: STUSDS cap already zeroed");
            assertNotEq(maxCap, 0, "before: STUSDS_RATE_SETTER maxCap already zeroed");
        }
        assertFalse(spell.done(), "before: spell already done");

        if (flow == Flow.LINE || flow == Flow.BOTH) {
            vm.expectEmit(true, true, true, false, address(spell));
            emit ZeroLine();
        }
        if (flow == Flow.CAP || flow == Flow.BOTH) {
            vm.expectEmit(true, true, true, false, address(spell));
            emit ZeroCap();
        }

        spell.schedule();

        uint256 postCap = stUsds.cap();
        uint256 postLine = stUsds.line();
        uint256 postMaxCap = stUsdsRateSetter.maxCap();
        uint256 postMaxLine = stUsdsRateSetter.maxLine();

        if (flow == Flow.LINE || flow == Flow.BOTH) {
            assertEq(postLine, 0, "after: STUSDS line non zeroed unexpectedly");
            assertEq(postMaxLine, 0, "after: STUSDS_RATE_SETTER maxLine non zeroed unexpectedly");
        }
        if (flow == Flow.CAP || flow == Flow.BOTH) {
            assertEq(postCap, 0, "after: STUSDS cap non zeroed unexpectedly");
            assertEq(postMaxCap, 0, "after: STUSDS_RATE_SETTER maxCap non zeroed unexpectedly");
        }
        assertTrue(spell.done(), "after: spell not done");
    }

    function _checkDoneWhenStUsdsMomIsNotWardInStUsds(Flow flow) internal {
        DssEmergencySpellLike spell = DssEmergencySpellLike(factory.deploy(flow));

        address pauseProxy = dss.chainlog.getAddress("MCD_PAUSE_PROXY");
        vm.prank(pauseProxy);
        stUsds.deny(stUsdsMom);

        assertTrue(spell.done(), "spell not done");
    }

    function _checkDoneWhenStUsdsRateSetterIsNotWardInStUsds(Flow flow) internal {
        DssEmergencySpellLike spell = DssEmergencySpellLike(factory.deploy(flow));

        address pauseProxy = dss.chainlog.getAddress("MCD_PAUSE_PROXY");
        vm.prank(pauseProxy);
        stUsds.deny(address(stUsdsRateSetter));

        assertTrue(spell.done(), "spell not done");
    }

    function _checkDoneWhenStUsdsMomIsNotWardInStUsdsRateSetter(Flow flow) internal {
        DssEmergencySpellLike spell = DssEmergencySpellLike(factory.deploy(flow));

        address pauseProxy = dss.chainlog.getAddress("MCD_PAUSE_PROXY");
        vm.prank(pauseProxy);
        stUsdsRateSetter.deny(stUsdsMom);

        assertTrue(spell.done(), "spell not done");
    }

    function _checkRevertSpellWhenItDoesNotHaveTheHat(Flow flow) internal {
        DssEmergencySpellLike spell = DssEmergencySpellLike(factory.deploy(flow));

        uint256 cap = stUsds.cap();
        uint256 line = stUsds.line();
        uint256 maxCap = stUsdsRateSetter.maxCap();
        uint256 maxLine = stUsdsRateSetter.maxLine();

        if (flow == Flow.LINE || flow == Flow.BOTH) {
            assertNotEq(line, 0, "before: STUSDS line already zeroed");
            assertNotEq(maxLine, 0, "before: STUSDS_RATE_SETTER maxLine already zeroed");
        }
        if (flow == Flow.CAP || flow == Flow.BOTH) {
            assertNotEq(cap, 0, "before: STUSDS cap already zeroed");
            assertNotEq(maxCap, 0, "before: STUSDS_RATE_SETTER maxCap already zeroed");
        }
        assertFalse(spell.done(), "before: spell already done");

        vm.expectRevert();
        spell.schedule();

        uint256 postCap = stUsds.cap();
        uint256 postLine = stUsds.line();
        uint256 postMaxCap = stUsdsRateSetter.maxCap();
        uint256 postMaxLine = stUsdsRateSetter.maxLine();

        if (flow == Flow.LINE || flow == Flow.BOTH) {
            assertEq(postLine, line, "after: STUSDS line zeroed unexpectedly");
            assertEq(postMaxLine, maxLine, "after: STUSDS_RATE_SETTER maxLine zeroed unexpectedly");
        }
        if (flow == Flow.CAP || flow == Flow.BOTH) {
            assertEq(postCap, cap, "after: STUSDS cap zeroed unexpectedly");
            assertEq(postMaxCap, maxCap, "after: STUSDS_RATE_SETTER maxCap zeroed unexpectedly");
        }
        assertFalse(spell.done(), "after: spell done unexpectedly");
    }

    event ZeroCap();
    event ZeroLine();
}
