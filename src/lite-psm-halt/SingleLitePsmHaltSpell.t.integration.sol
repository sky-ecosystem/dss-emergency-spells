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
import {DssTest, DssInstance, MCD, GodMode} from "dss-test/DssTest.sol";
import {DssEmergencySpellLike} from "../DssEmergencySpell.sol";
import {SingleLitePsmHaltFactory, Flow} from "./SingleLitePsmHaltSpell.sol";

interface LitePsmLike {
    function deny(address) external;
    function ilk() external view returns (bytes32);
    function tin() external view returns (uint256);
    function tout() external view returns (uint256);
    function HALTED() external view returns (uint256);
    function wards(address) external view returns (uint256);
}

contract MockAuth {
    function wards(address) external pure returns (uint256) {
        return 1;
    }
}

contract MockPsmHaltedReverts is MockAuth {
    function HALTED() external pure {
        revert();
    }
}

contract SingleLitePsmHaltSpellTest is DssTest {
    using stdStorage for StdStorage;

    address constant CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;
    DssInstance dss;
    address chief;
    address litePsmMom;
    LitePsmLike psm;
    SingleLitePsmHaltFactory factory;

    function setUp() public {
        vm.createSelectFork("mainnet");

        dss = MCD.loadFromChainlog(CHAINLOG);
        MCD.giveAdminAccess(dss);
        chief = dss.chainlog.getAddress("MCD_ADM");
        litePsmMom = dss.chainlog.getAddress("LITE_PSM_MOM");
        psm = LitePsmLike(dss.chainlog.getAddress("MCD_LITE_PSM_USDC_A"));
        factory = new SingleLitePsmHaltFactory();
    }

    function testPsmHaltOnScheduleBuy() public {
        _checkPsmHaltOnSchedule(Flow.BUY);
    }

    function testPsmHaltOnScheduleSell() public {
        _checkPsmHaltOnSchedule(Flow.SELL);
    }

    function testPsmHaltOnScheduleBoth() public {
        _checkPsmHaltOnSchedule(Flow.BOTH);
    }

    function _checkPsmHaltOnSchedule(Flow flow) internal {
        DssEmergencySpellLike spell = DssEmergencySpellLike(factory.deploy(address(psm), flow));
        stdstore.target(chief).sig("hat()").checked_write(address(spell));
        vm.makePersistent(chief);

        uint256 preTin = psm.tin();
        uint256 preTout = psm.tout();
        uint256 halted = psm.HALTED();

        if (flow == Flow.SELL || flow == Flow.BOTH) {
            assertNotEq(preTin, halted, "before: PSM SELL already halted");
        }
        if (flow == Flow.BUY || flow == Flow.BOTH) {
            assertNotEq(preTout, halted, "before: PSM BUY already halted");
        }
        assertFalse(spell.done(), "before: spell already done");

        vm.expectEmit(true, true, true, false, address(spell));
        emit Halt(flow);

        spell.schedule();

        uint256 postTin = psm.tin();
        uint256 postTout = psm.tout();

        if (flow == Flow.SELL || flow == Flow.BOTH) {
            assertEq(postTin, halted, "after: PSM SELL not halted (tin)");
        }
        if (flow == Flow.BUY || flow == Flow.BOTH) {
            assertEq(postTout, halted, "after: PSM BUY not halted (tout)");
        }

        assertTrue(spell.done(), "after: spell not done");
    }

    function testDoneWhenLitePsmMomIsNotWardInPsm() public {
        DssEmergencySpellLike spell = DssEmergencySpellLike(factory.deploy(address(psm), Flow.BUY));

        address pauseProxy = dss.chainlog.getAddress("MCD_PAUSE_PROXY");
        vm.prank(pauseProxy);
        psm.deny(address(litePsmMom));

        assertTrue(spell.done(), "spell not done");
    }

    function testDoneWhenLitePsmDoesNotImplementHalted() public {
        psm = LitePsmLike(address(new MockAuth()));
        DssEmergencySpellLike spell = DssEmergencySpellLike(factory.deploy(address(psm), Flow.BUY));

        assertTrue(spell.done(), "spell not done");
    }

    function testDoneWhenLitePsmHaltedReverts() public {
        psm = LitePsmLike(address(new MockPsmHaltedReverts()));
        DssEmergencySpellLike spell = DssEmergencySpellLike(factory.deploy(address(psm), Flow.BUY));

        assertTrue(spell.done(), "spell not done");
    }

    function testRevertPsmHaltWhenItDoesNotHaveTheHat() public {
        Flow flow = Flow.BOTH;
        DssEmergencySpellLike spell = DssEmergencySpellLike(factory.deploy(address(psm), flow));

        uint256 preTin = psm.tin();
        uint256 preTout = psm.tout();
        uint256 halted = psm.HALTED();

        if (flow == Flow.SELL || flow == Flow.BOTH) {
            assertNotEq(preTin, halted, "before: PSM SELL already halted");
        }
        if (flow == Flow.BUY || flow == Flow.BOTH) {
            assertNotEq(preTout, halted, "before: PSM BUY already halted");
        }
        assertFalse(spell.done(), "before: spell already done");

        vm.expectRevert();
        spell.schedule();

        uint256 postTin = psm.tin();
        uint256 postTout = psm.tout();

        if (flow == Flow.SELL || flow == Flow.BOTH) {
            assertEq(postTin, preTin, "after: PSM SELL halted unexpectedly (tin)");
        }
        if (flow == Flow.BUY || flow == Flow.BOTH) {
            assertEq(postTout, preTout, "after: PSM BUY halted unexpectedly (tout)");
        }

        assertFalse(spell.done(), "after: spell done unexpectedly");
    }

    function testDoneWhenPsmToMomWardReverts() public {
        Flow flow = Flow.BOTH;
        DssEmergencySpellLike spell = DssEmergencySpellLike(factory.deploy(address(psm), flow));
        // Mock psm.wards(litePsmMom) to revert
        vm.mockCallRevert(
            address(psm), abi.encodeWithSelector(LitePsmLike.wards.selector, address(litePsmMom)), "revert"
        );

        assertTrue(spell.done(), "spell not done");
    }

    // Description

    function testDescriptionCap() public {
        _checkDescription(Flow.SELL);
    }

    function testDescriptionLine() public {
        _checkDescription(Flow.BUY);
    }

    function testDescriptionBoth() public {
        _checkDescription(Flow.BOTH);
    }

    function _checkDescription(Flow flow) internal {
        DssEmergencySpellLike spell = DssEmergencySpellLike(factory.deploy(address(psm), flow));

        stdstore.target(chief).sig("hat()").checked_write(address(spell));
        string memory description = spell.description();
        if (flow == Flow.SELL) {
            assertEq(description, string(abi.encodePacked("Emergency Spell | ", psm.ilk(), " | halt: SELL")));
        } else if (flow == Flow.BUY) {
            assertEq(description, string(abi.encodePacked("Emergency Spell | ", psm.ilk(), " | halt: BUY")));
        } else {
            assertEq(description, string(abi.encodePacked("Emergency Spell | ", psm.ilk(), " | halt: BOTH")));
        }
    }

    event Halt(Flow what);
}
