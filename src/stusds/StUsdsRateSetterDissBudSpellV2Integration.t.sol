// SPDX-FileCopyrightText: © 2026 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {stdStorage, StdStorage} from "forge-std/Test.sol";
import {DssInstance, DssTest, MCD} from "dss-test/DssTest.sol";

import {StUsdsRateSetterDissBudSpellV2} from "./StUsdsRateSetterDissBudSpellV2.sol";

contract StUsdsRateSetterDissBudSpellV2IntegrationTest is DssTest {
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

    function testStUsdsRateSetterDissBudV2OnMainnet() public {
        address rateSetter = dss.chainlog.getAddress("STUSDS_RATE_SETTER");
        address bud = makeAddr("bud");
        stdstore.target(rateSetter).sig("buds(address)").with_key(bud).checked_write(uint256(1));
        StUsdsRateSetterDissBudSpellV2 spell =
            new StUsdsRateSetterDissBudSpellV2(dss.chainlog.getAddress("STUSDS_MOM"), rateSetter, bud);
        stdstore.target(chief).sig("hat()").checked_write(address(spell));

        assertFalse(spell.done());
        spell.schedule();
        assertTrue(spell.done());
    }
}
