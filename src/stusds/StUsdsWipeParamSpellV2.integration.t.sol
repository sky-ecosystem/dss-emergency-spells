// SPDX-FileCopyrightText: © 2026 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {stdStorage, StdStorage} from "forge-std/Test.sol";
import {DssInstance, DssTest, MCD} from "dss-test/DssTest.sol";

import {Param, StUsdsWipeParamSpellV2} from "./StUsdsWipeParamSpellV2.sol";

contract StUsdsWipeParamSpellV2IntegrationTest is DssTest {
    using stdStorage for StdStorage;

    address internal constant CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;

    DssInstance internal dss;
    address internal chief;

    function setUp() public {
        vm.createSelectFork("mainnet");
        dss = MCD.loadFromChainlog(CHAINLOG);
        MCD.giveAdminAccess(dss);
        chief = dss.chainlog.getAddress("MCD_ADM");
        vm.makePersistent(chief);
    }

    function testStUsdsWipeParamV2OnMainnet() public {
        address stUsds = dss.chainlog.getAddress("STUSDS");
        address rateSetter = dss.chainlog.getAddress("STUSDS_RATE_SETTER");
        stdstore.target(stUsds).sig("line()").checked_write(1_000_000 * RAD);
        stdstore.target(stUsds).sig("cap()").checked_write(1_000_000 * WAD);
        stdstore.target(rateSetter).sig("maxLine()").checked_write(1_000_000 * RAD);
        stdstore.target(rateSetter).sig("maxCap()").checked_write(1_000_000 * WAD);
        StUsdsWipeParamSpellV2 spell =
            new StUsdsWipeParamSpellV2(dss.chainlog.getAddress("STUSDS_MOM"), rateSetter, stUsds, Param.BOTH);
        stdstore.target(chief).sig("hat()").checked_write(address(spell));

        assertFalse(spell.done());
        spell.schedule();
        assertTrue(spell.done());
    }
}
