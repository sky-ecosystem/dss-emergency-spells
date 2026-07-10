// SPDX-FileCopyrightText: © 2026 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {DssInstance, DssTest, MCD} from "dss-test/DssTest.sol";

import {SplitterStopSpellV2DeployScript} from "../../../script/splitter-stop/DeploySplitterStopV2.s.sol";
import {SplitterStopSpellV2} from "../../../src/splitter-stop/SplitterStopSpellV2.sol";

contract DeploySplitterStopV2IntegrationTest is DssTest {
    address internal constant CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;

    DssInstance internal dss;

    function setUp() public {
        vm.createSelectFork("mainnet");
        dss = MCD.loadFromChainlog(CHAINLOG);
    }

    function testChainlogEntrypointOnMainnet() public {
        SplitterStopSpellV2 spell = SplitterStopSpellV2(new SplitterStopSpellV2DeployScript().run());
        assertEq(spell.splitterMom(), dss.chainlog.getAddress("SPLITTER_MOM"));
        assertEq(spell.splitter(), dss.chainlog.getAddress("MCD_SPLIT"));
    }
}
