// SPDX-FileCopyrightText: © 2026 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {DssInstance, DssTest, MCD} from "dss-test/DssTest.sol";

import {SPBEAMHaltSpellV2DeployScript} from "./DeploySPBEAMHaltV2.s.sol";
import {SPBEAMHaltSpellV2} from "../../src/spbeam-halt/SPBEAMHaltSpellV2.sol";

contract DeploySPBEAMHaltV2IntegrationTest is DssTest {
    address internal constant CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;

    DssInstance internal dss;

    function setUp() public {
        vm.createSelectFork("mainnet");
        dss = MCD.loadFromChainlog(CHAINLOG);
    }

    function testChainlogEntrypointOnMainnet() public {
        SPBEAMHaltSpellV2 spell = SPBEAMHaltSpellV2(new SPBEAMHaltSpellV2DeployScript().run());
        assertEq(spell.spbeamMom(), dss.chainlog.getAddress("SPBEAM_MOM"));
        assertEq(spell.spbeam(), dss.chainlog.getAddress("MCD_SPBEAM"));
    }
}
