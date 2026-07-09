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
import {SingleLineWipeFactory} from "./SingleLineWipeSpell.sol";

interface AutoLineLike {
    function ilks(bytes32 ilk)
        external
        view
        returns (uint256 maxLine, uint256 gap, uint48 ttl, uint48 last, uint48 lastInc);
}

interface LineMomLike {
    function delIlk(bytes32 ilk) external;
}

interface VatLike {
    function file(bytes32 ilk, bytes32 what, uint256 data) external;
}

contract SingleLineWipeSpellTest is DssTest {
    using stdStorage for StdStorage;

    address constant CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;
    DssInstance dss;
    VatLike vat;
    address chief;
    bytes32 ilk = "ETH-A";
    LineMomLike lineMom;
    AutoLineLike autoLine;
    SingleLineWipeFactory factory;
    DssEmergencySpellLike spell;

    function setUp() public {
        vm.createSelectFork("mainnet");

        dss = MCD.loadFromChainlog(CHAINLOG);
        MCD.giveAdminAccess(dss);
        chief = dss.chainlog.getAddress("MCD_ADM");
        vat = VatLike(dss.chainlog.getAddress("MCD_VAT"));
        lineMom = LineMomLike(dss.chainlog.getAddress("LINE_MOM"));
        autoLine = AutoLineLike(dss.chainlog.getAddress("MCD_IAM_AUTO_LINE"));
        factory = new SingleLineWipeFactory();
        spell = DssEmergencySpellLike(factory.deploy(ilk));

        stdstore.target(chief).sig("hat()").checked_write(address(spell));

        vm.makePersistent(chief);
    }

    function testLineWipeOnSchedule() public {
        (uint256 pmaxLine, uint256 pgap,,,) = autoLine.ilks(ilk);
        assertGt(pmaxLine, 0, "before: auto-line maxLine already wiped");
        assertGt(pgap, 0, "before: auto-line gap already wiped");
        assertFalse(spell.done(), "before: spell already done");

        vm.expectEmit(true, true, true, false);
        emit Wipe();
        spell.schedule();

        (uint256 maxLine, uint256 gap,,,) = autoLine.ilks(ilk);
        assertEq(maxLine, 0, "after: auto-line maxLine not wiped");
        assertEq(gap, 0, "after: auto-line gap not wiped");
        assertTrue(spell.done(), "after: spell not done");
    }

    function testDoneWhenIlkIsNotAddedToLineMom() public {
        address pauseProxy = dss.chainlog.getAddress("MCD_PAUSE_PROXY");
        vm.prank(pauseProxy);
        lineMom.delIlk(ilk);

        assertTrue(spell.done(), "spell not done");
    }

    function testDoneWhenAutoLineIsNotActiveButLineIsNonZero() public {
        spell.schedule();
        assertTrue(spell.done(), "before: spell not done");

        address pauseProxy = dss.chainlog.getAddress("MCD_PAUSE_PROXY");
        vm.prank(pauseProxy);
        vat.file(ilk, "line", 10 ** 45);

        assertFalse(spell.done(), "after: spell still done");
    }

    function testRevertLineWipeWhenItDoesNotHaveTheHat() public {
        stdstore.target(chief).sig("hat()").checked_write(address(0));

        (uint256 pmaxLine, uint256 pgap,,,) = autoLine.ilks(ilk);
        assertGt(pmaxLine, 0, "before: auto-line maxLine already wiped");
        assertGt(pgap, 0, "before: auto-line gap already wiped");
        assertFalse(spell.done(), "before: spell already done");

        vm.expectRevert();
        spell.schedule();

        (uint256 maxLine, uint256 gap,,,) = autoLine.ilks(ilk);
        assertGt(maxLine, 0, "after: auto-line maxLine wiped unexpectedly");
        assertGt(gap, 0, "after: auto-line gap wiped unexpectedly");
        assertFalse(spell.done(), "after: spell done unexpectedly");
    }

    function testDescription() public view {
        assertEq(spell.description(), string(abi.encodePacked("Emergency Spell | Line Wipe: ", ilk)));
    }

    event Wipe();
}
