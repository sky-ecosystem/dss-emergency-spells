// SPDX-FileCopyrightText: © 2026 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {stdStorage, StdStorage} from "forge-std/Test.sol";
import {DssInstance, DssTest, MCD} from "dss-test/DssTest.sol";

import {LineWipeSpellV2} from "./LineWipeSpellV2.sol";

contract LineWipeSpellV2IntegrationTest is DssTest {
    using stdStorage for StdStorage;

    address internal constant CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;
    bytes32 internal constant ILK = "ETH-A";

    DssInstance internal dss;
    address internal chief;

    function setUp() public {
        vm.createSelectFork("mainnet");
        dss = MCD.loadFromChainlog(CHAINLOG);
        MCD.giveAdminAccess(dss);
        chief = dss.chainlog.getAddress("MCD_ADM");
        vm.makePersistent(chief);
    }

    function testLineWipeV2OnMainnet() public {
        LineWipeSpellV2 spell = new LineWipeSpellV2(dss.chainlog.getAddress("LINE_MOM"), ILK);
        stdstore.target(chief).sig("hat()").checked_write(address(spell));

        assertFalse(spell.done());
        spell.schedule();
        assertTrue(spell.done());
    }
}
