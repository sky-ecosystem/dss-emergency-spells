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
import {MultiLineWipeSpell} from "./MultiLineWipeSpell.sol";

interface LineMomLike {
    function ilks(bytes32 ilk) external view returns (uint256);
    function autoLine() external view returns (address);
}

interface IlkRegistryLike {
    function count() external view returns (uint256);
    function list() external view returns (bytes32[] memory);
    function list(uint256 start, uint256 end) external view returns (bytes32[] memory);
}

interface AutoLineLike {
    function ilks(bytes32 ilk)
        external
        view
        returns (uint256 maxLine, uint256 gap, uint48 ttl, uint48 last, uint48 lastInc);
    function wards(address who) external view returns (uint256);
}

interface VatLike {
    function file(bytes32 ilk, bytes32 what, uint256 data) external;
    function wards(address who) external view returns (uint256);
}

contract MultiLineWipeSpellTest is DssTest {
    using stdStorage for StdStorage;

    address constant CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;
    DssInstance dss;
    address chief;
    VatLike vat;
    IlkRegistryLike ilkReg;
    LineMomLike lineMom;
    AutoLineLike autoLine;
    MultiLineWipeSpell spell;

    mapping(bytes32 => bool) ilksToIgnore;

    function setUp() public {
        vm.createSelectFork("mainnet");

        dss = MCD.loadFromChainlog(CHAINLOG);
        MCD.giveAdminAccess(dss);
        chief = dss.chainlog.getAddress("MCD_ADM");
        vat = VatLike(dss.chainlog.getAddress("MCD_VAT"));
        ilkReg = IlkRegistryLike(dss.chainlog.getAddress("ILK_REGISTRY"));
        lineMom = LineMomLike(dss.chainlog.getAddress("LINE_MOM"));
        autoLine = AutoLineLike(lineMom.autoLine());
        spell = new MultiLineWipeSpell();

        stdstore.target(chief).sig("hat()").checked_write(address(spell));

        _initIlksToIgnore();

        vm.makePersistent(chief);
    }

    /// @dev Ignore any of:
    ///      - ilk was not set in LineMom
    ///      - ilk line is already zero and/or wiped from auto-line
    function _initIlksToIgnore() internal {
        bytes32[] memory ilks = ilkReg.list();
        for (uint256 i = 0; i < ilks.length; i++) {
            string memory ilkStr = string(abi.encodePacked(ilks[i]));
            if (lineMom.ilks(ilks[i]) == 0) {
                ilksToIgnore[ilks[i]] = true;
                emit log_named_string("Ignoring ilk | LineMom not set", ilkStr);
                continue;
            }

            (uint256 maxLine, uint256 gap, uint48 ttl, uint48 last, uint48 lastInc) = autoLine.ilks(ilks[i]);
            if (maxLine == 0 && gap == 0 && ttl == 0 && last == 0 && lastInc == 0) {
                ilksToIgnore[ilks[i]] = true;
                emit log_named_string("Ignoring ilk | Already wiped", ilkStr);
                continue;
            }
        }
    }

    function testMultiOracleStopOnSchedule() public {
        _checkLineWipedStatus({ilks: ilkReg.list(), expected: false});
        assertFalse(spell.done(), "before: spell already done");

        spell.schedule();

        _checkLineWipedStatus({ilks: ilkReg.list(), expected: true});
        assertTrue(spell.done(), "after: spell not done");
    }

    function testMultiOracleStopInBatches_Fuzz(uint256 batchSize) public {
        batchSize = bound(batchSize, 1, type(uint128).max);
        uint256 count = ilkReg.count();
        uint256 maxEnd = count - 1;
        uint256 start = 0;
        // End is inclusive, so we need to subtract 1
        uint256 end = start + batchSize - 1;

        _checkLineWipedStatus({ilks: ilkReg.list(), expected: false});

        while (start < count) {
            spell.stopBatch(start, end);
            _checkLineWipedStatus({ilks: ilkReg.list(start, end < maxEnd ? end : maxEnd), expected: true});

            start += batchSize;
            end += batchSize;
        }

        // Sanity check: the test iterated over the entire ilk registry.
        _checkLineWipedStatus({ilks: ilkReg.list(), expected: true});
    }

    function testDoneWhenAutoLineIsNotActiveButLineIsNonZero() public {
        spell.schedule();
        assertTrue(spell.done(), "before: spell not done");

        address pauseProxy = dss.chainlog.getAddress("MCD_PAUSE_PROXY");
        vm.prank(pauseProxy);
        vat.file("ETH-A", "line", 10 ** 45);

        assertFalse(spell.done(), "after: spell still done");
    }

    function testDoneWhenLineMomIsNotWardInVat() public {
        vm.mockCall(address(vat), abi.encodeWithSelector(VatLike.wards.selector, address(lineMom)), abi.encode(uint256(0)));

        assertTrue(spell.done(), "spell not done");
    }

    function testDoneWhenLineMomIsNotWardInAutoLine() public {
        vm.mockCall(address(vat), abi.encodeWithSelector(VatLike.wards.selector, address(lineMom)), abi.encode(uint256(1)));
        vm.mockCall(
            address(autoLine), abi.encodeWithSelector(AutoLineLike.wards.selector, address(lineMom)), abi.encode(uint256(0))
        );

        assertTrue(spell.done(), "spell not done");
    }

    function testRevertMultiOracleStopWhenItDoesNotHaveTheHat() public {
        stdstore.target(chief).sig("hat()").checked_write(address(0));

        _checkLineWipedStatus({ilks: ilkReg.list(), expected: false});

        vm.expectRevert();
        spell.schedule();
    }

    function _checkLineWipedStatus(bytes32[] memory ilks, bool expected) internal view {
        assertTrue(ilks.length > 0, "empty ilks list");

        for (uint256 i = 0; i < ilks.length; i++) {
            if (ilksToIgnore[ilks[i]]) continue;

            (uint256 maxLine, uint256 gap, uint48 ttl, uint48 last, uint48 lastInc) = autoLine.ilks(ilks[i]);
            assertEq(
                maxLine == 0 && gap == 0 && ttl == 0 && last == 0 && lastInc == 0,
                expected,
                string(abi.encodePacked("invalid wiped status: ", ilks[i]))
            );
        }
    }
}
