// SPDX-FileCopyrightText: © 2026 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {stdStorage, StdStorage} from "forge-std/Test.sol";
import {DssInstance, DssTest, MCD} from "dss-test/DssTest.sol";

import {DdmDisableSpellV2} from "./DdmDisableSpellV2.sol";

interface DdmHubForDdmDisable {
    function plan(bytes32 ilk) external view returns (address);
}

contract DdmDisableSpellV2IntegrationTest is DssTest {
    using stdStorage for StdStorage;

    address internal constant CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;
    bytes32 internal constant ILK = "DIRECT-SPARK-DAI";

    DssInstance internal dss;
    address internal chief;

    function setUp() public {
        vm.createSelectFork("mainnet");
        dss = MCD.loadFromChainlog(CHAINLOG);
        MCD.giveAdminAccess(dss);
        chief = dss.chainlog.getAddress("MCD_ADM");
        vm.makePersistent(chief);
    }

    function testDdmDisableV2OnMainnet() public {
        address plan = DdmHubForDdmDisable(dss.chainlog.getAddress("DIRECT_HUB")).plan(ILK);
        DdmDisableSpellV2 spell = new DdmDisableSpellV2(dss.chainlog.getAddress("DIRECT_MOM"), plan, ILK);
        stdstore.target(chief).sig("hat()").checked_write(address(spell));

        assertFalse(spell.done());
        spell.schedule();
        assertTrue(spell.done());
    }
}
