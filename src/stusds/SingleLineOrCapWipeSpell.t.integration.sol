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
import {SingleLineOrCapWipeFactory, Flow} from "./SingleLineOrCapWipeSpell.sol";

interface StUsdsRateSetterLike {
    function maxLine() external view returns (uint256);
    function maxCap() external view returns (uint256);
}

interface StUsdsLike {
    function deny(address) external;
    function line() external view returns (uint256);
    function cap() external view returns (uint256);
    function wards(address) external view returns (uint256);
}

interface StUsdsMomLike {}

contract SingleLinePsmHaltSpellTest is DssTest {
    using stdStorage for StdStorage;

    address constant CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;
    DssInstance dss;
    address chief;
    StUsdsMomLike stUsdsMom;
    StUsdsLike stUsds;
    StUsdsRateSetterLike stUsdsRateSetter;
    SingleLineOrCapWipeFactory factory;

    function setUp() public {
        vm.createSelectFork("mainnet");

        dss = MCD.loadFromChainlog(CHAINLOG);
        MCD.giveAdminAccess(dss);
        chief = dss.chainlog.getAddress("MCD_ADM");
        stUsdsMom = StUsdsMomLike(dss.chainlog.getAddress("STUSDS_MOM"));
        stUsds = StUsdsLike(dss.chainlog.getAddress("STUSDS"));
        stUsdsRateSetter = StUsdsRateSetterLike(dss.chainlog.getAddress("STUSDS_RATE_SETTER"));
        factory = new SingleLineOrCapWipeFactory();
    }

    function testPsmHaltOnScheduleLine() public {
        _checkPsmHaltOnSchedule(Flow.LINE);
    }

    function testPsmHaltOnScheduleCap() public {
        _checkPsmHaltOnSchedule(Flow.CAP);
    }

    function testPsmHaltOnScheduleBoth() public {
        _checkPsmHaltOnSchedule(Flow.BOTH);
    }

    function testDoneWhenStUsdsMomIsNotWardInStUsdsLine() public {
        _checkDoneWhenStUsdsMomIsNotWardInStUsds(Flow.LINE);
    }

    function testDoneWhenStUsdsMomIsNotWardInStUsdsCap() public {
        _checkDoneWhenStUsdsMomIsNotWardInStUsds(Flow.CAP);
    }

    function testDoneWhenStUsdsMomIsNotWardInStUsdsBoth() public {
        _checkDoneWhenStUsdsMomIsNotWardInStUsds(Flow.BOTH);
    }

    function testDoneWhenStUsdsRateSetterIsNotWardInStUsdsLine() public {
        _checkDoneWhenStUsdsRateSetterIsNotWardInStUsds(Flow.LINE);
    }

    function testDoneWhenStUsdsRateSetterIsNotWardInStUsdsCap() public {
        _checkDoneWhenStUsdsRateSetterIsNotWardInStUsds(Flow.CAP);
    }

    function testDoneWhenStUsdsRateSetterIsNotWardInStUsdsBoth() public {
        _checkDoneWhenStUsdsRateSetterIsNotWardInStUsds(Flow.BOTH);
    }

    function testRevertSpellWhenItDoesNotHaveTheHatLine() public {
        _checkRevertSpellWhenItDoesNotHaveTheHat(Flow.LINE);
    }

    function testRevertSpellWhenItDoesNotHaveTheHatCap() public {
        _checkRevertSpellWhenItDoesNotHaveTheHat(Flow.CAP);
    }

    function testRevertSpellWhenItDoesNotHaveTheHatBoth() public {
        _checkRevertSpellWhenItDoesNotHaveTheHat(Flow.BOTH);
    }

    function _checkPsmHaltOnSchedule(Flow flow) internal {
        DssEmergencySpellLike spell = DssEmergencySpellLike(factory.deploy(address(stUsdsRateSetter), address(stUsdsMom), address(stUsds), flow));
        stdstore.target(chief).sig("hat()").checked_write(address(spell));
        vm.makePersistent(chief);

        uint256 line = stUsds.line();
        uint256 cap = stUsds.cap();
        uint256 maxLine = stUsdsRateSetter.maxLine();
        uint256 maxCap = stUsdsRateSetter.maxCap();
        
        if (flow == Flow.LINE || flow == Flow.BOTH) {
            assertNotEq(line, 0, "before: STUSDS line already zeroed");
            assertNotEq(maxLine, 0, "before: STUSDS_RATE_SETTER maxLine already zeroed");
        }
        if (flow == Flow.CAP || flow == Flow.BOTH) {
            assertNotEq(cap, 0, "before: STUSDS cap already zeroed");
            assertNotEq(maxCap, 0, "before: STUSDS_RATE_SETTER maxCap already zeroed");
        }
        assertFalse(spell.done(), "before: spell already done");

        vm.expectEmit(true, true, true, false, address(spell));
        emit ZeroCapOrLine(flow);

        spell.schedule();

        uint256 postLine = stUsds.line();
        uint256 postCap = stUsds.cap();
        uint256 postMaxLine = stUsdsRateSetter.maxLine();
        uint256 postMaxCap = stUsdsRateSetter.maxCap();

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
        DssEmergencySpellLike spell = DssEmergencySpellLike(factory.deploy(address(stUsdsRateSetter), address(stUsdsMom), address(stUsds), flow));

        address pauseProxy = dss.chainlog.getAddress("MCD_PAUSE_PROXY");
        vm.prank(pauseProxy);
        stUsds.deny(address(stUsdsMom));

        assertTrue(spell.done(), "spell not done");
    }

    function _checkDoneWhenStUsdsRateSetterIsNotWardInStUsds(Flow flow) internal {
        DssEmergencySpellLike spell = DssEmergencySpellLike(factory.deploy(address(stUsdsRateSetter), address(stUsdsMom), address(stUsds), flow));

        address pauseProxy = dss.chainlog.getAddress("MCD_PAUSE_PROXY");
        vm.prank(pauseProxy);
        stUsds.deny(address(stUsdsRateSetter));

        assertTrue(spell.done(), "spell not done");
    }

    function _checkRevertSpellWhenItDoesNotHaveTheHat(Flow flow) internal {
        DssEmergencySpellLike spell = DssEmergencySpellLike(factory.deploy(address(stUsdsRateSetter), address(stUsdsMom), address(stUsds), flow));

        uint256 line = stUsds.line();
        uint256 cap = stUsds.cap();
        uint256 maxLine = stUsdsRateSetter.maxLine();
        uint256 maxCap = stUsdsRateSetter.maxCap();

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

        uint256 postLine = stUsds.line();
        uint256 postCap = stUsds.cap();
        uint256 postMaxLine = stUsdsRateSetter.maxLine();
        uint256 postMaxCap = stUsdsRateSetter.maxCap();

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

    event ZeroCapOrLine(Flow what);
}
