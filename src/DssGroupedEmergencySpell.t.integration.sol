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

import {DssTest, DssInstance, MCD} from "dss-test/DssTest.sol";
import {DssGroupedEmergencySpell} from "./DssGroupedEmergencySpell.sol";

contract DssGroupedEmergencySpellImpl is DssGroupedEmergencySpell {
    mapping(bytes32 => bool) public isDone;

    function setDone(bytes32 ilk, bool val) external {
        isDone[ilk] = val;
    }

    function _descriptionPrefix() internal pure override returns (string memory) {
        return "Grouped Emergency Spell:";
    }

    event EmergencyAction(bytes32 indexed ilk);

    constructor(bytes32[] memory _ilks) DssGroupedEmergencySpell(_ilks) {}

    function _emergencyActions(bytes32 ilk) internal override {
        emit EmergencyAction(ilk);
        isDone[ilk] = true;
    }

    function _done(bytes32 ilk) internal view override returns (bool) {
        return isDone[ilk];
    }
}

contract DssGroupedEmergencySpellTest is DssTest {
    address constant CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;
    DssInstance dss;
    DssGroupedEmergencySpellImpl spell2;
    DssGroupedEmergencySpellImpl spell3;
    DssGroupedEmergencySpellImpl spellN;
    address pause;

    function setUp() public {
        vm.createSelectFork("mainnet");

        dss = MCD.loadFromChainlog(CHAINLOG);
        MCD.giveAdminAccess(dss);
        pause = dss.chainlog.getAddress("MCD_PAUSE");

        bytes32[] memory ilks2 = new bytes32[](2);
        ilks2[0] = "WSTETH-A";
        ilks2[1] = "WSTETH-B";
        spell2 = new DssGroupedEmergencySpellImpl(ilks2);
        bytes32[] memory ilks3 = new bytes32[](3);
        ilks3[0] = "ETH-A";
        ilks3[1] = "ETH-B";
        ilks3[2] = "ETH-C";
        spell3 = new DssGroupedEmergencySpellImpl(ilks3);
        bytes32[] memory ilksN = new bytes32[](8);
        ilksN[0] = "ETH-A";
        ilksN[1] = "ETH-B";
        ilksN[2] = "ETH-C";
        ilksN[3] = "WSTETH-A";
        ilksN[4] = "WSTETH-B";
        ilksN[5] = "WBTC-A";
        ilksN[6] = "WBTC-B";
        ilksN[7] = "WBTC-C";
        spellN = new DssGroupedEmergencySpellImpl(ilksN);
    }

    function testDescription() public view {
        assertEq(spell2.description(), "Grouped Emergency Spell: WSTETH-A, WSTETH-B");
        assertEq(spell3.description(), "Grouped Emergency Spell: ETH-A, ETH-B, ETH-C");
    }

    function testRevertWhenTooFewIlks() public {
        bytes32[] memory ilks = new bytes32[](0);

        vm.expectRevert("DssGroupedEmergencySpell/too-few-ilks");
        new DssGroupedEmergencySpellImpl(ilks);
    }

    function testEmergencyActions() public {
        vm.expectEmit(true, true, true, true);
        emit EmergencyAction("WSTETH-A");
        vm.expectEmit(true, true, true, true);
        emit EmergencyAction("WSTETH-B");
        spell2.schedule();

        vm.expectEmit(true, true, true, true);
        emit EmergencyAction("ETH-A");
        vm.expectEmit(true, true, true, true);
        emit EmergencyAction("ETH-B");
        vm.expectEmit(true, true, true, true);
        emit EmergencyAction("ETH-C");
        spell3.schedule();

        vm.expectEmit(true, true, true, true);
        emit EmergencyAction("ETH-A");
        vm.expectEmit(true, true, true, true);
        emit EmergencyAction("ETH-B");
        vm.expectEmit(true, true, true, true);
        emit EmergencyAction("ETH-C");
        vm.expectEmit(true, true, true, true);
        emit EmergencyAction("WSTETH-A");
        vm.expectEmit(true, true, true, true);
        emit EmergencyAction("WSTETH-B");
        vm.expectEmit(true, true, true, true);
        emit EmergencyAction("WBTC-A");
        vm.expectEmit(true, true, true, true);
        emit EmergencyAction("WBTC-B");
        vm.expectEmit(true, true, true, true);
        emit EmergencyAction("WBTC-C");
        spellN.schedule();
    }

    function testEmergencyActionsInBatches_Fuzz(uint256 batchSize) public {
        uint256 count = spellN.ilks().length;
        batchSize = bound(batchSize, 1, count);
        uint256 start = 0;
        // End is inclusive, so we need to subtract 1
        uint256 end = start + batchSize - 1;

        assertFalse(spellN.done(), "spellN unexpectedly done");

        while (start < count) {
            spellN.emergencyActionsInBatch(start, end);

            start += batchSize;
            end += batchSize;
        }

        assertTrue(spellN.done(), "spellN not done");
    }

    function testRevertEmergencyActionsInBatchWhenStartIsGreaterThanEnd() public {
        vm.expectRevert("DssGroupedEmergencySpell/bad-iteration");
        spell2.emergencyActionsInBatch(2, 3);
    }

    function testDone() public {
        assertFalse(spell2.done(), "spell2 unexpectedly done");
        assertFalse(spell3.done(), "spell3 unexpectedly done");

        {
            // Tweak spell2 so it is considered done for WSTETH-A...
            spell2.setDone("WSTETH-A", true);
            // ... in this case it should still return false
            assertFalse(spell2.done(), "spell2 unexpectedly done");
            // Then set done for WSTETH-B...
            spell2.setDone("WSTETH-B", true);
            // ... new the spell must finally return true
            assertTrue(spell2.done(), "spell2 not done");
        }

        {
            // Tweak spell3 so it is considered done for ETH-A...
            spell3.setDone("ETH-A", true);
            // ... in this case it should still return false
            assertFalse(spell3.done(), "spell3 unexpectedly done");
            // Then set done for ETH-B...
            spell3.setDone("ETH-B", true);
            // ... it should still return false
            assertFalse(spell3.done(), "spell3 unexpectedly done");
            // Then set done for ETH-C...
            spell3.setDone("ETH-C", true);
            // ... now the spell must finally return true
            assertTrue(spell3.done(), "spell3 not done");
        }
    }

    event EmergencyAction(bytes32 indexed ilk);
}
