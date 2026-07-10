// SPDX-FileCopyrightText: © 2026 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {DssInstance, DssTest, MCD} from "dss-test/DssTest.sol";

import {GlobalLineWipeSpellV2DeployScript, LineWipeSpellV2DeployScript} from "./DeployLineWipeV2.s.sol";
import {GlobalLineWipeSpellV2} from "../../src/line-wipe/GlobalLineWipeSpellV2.sol";
import {LineWipeSpellV2} from "../../src/line-wipe/LineWipeSpellV2.sol";

contract DeployLineWipeV2IntegrationTest is DssTest {
    address internal constant CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;
    bytes32 internal constant ILK = "ETH-A";

    DssInstance internal dss;

    function setUp() public {
        vm.createSelectFork("mainnet");
        dss = MCD.loadFromChainlog(CHAINLOG);
    }

    function testChainlogEntrypointsOnMainnet() public {
        LineWipeSpellV2 leaf = LineWipeSpellV2(new LineWipeSpellV2DeployScript().run(ILK));
        GlobalLineWipeSpellV2 global = GlobalLineWipeSpellV2(new GlobalLineWipeSpellV2DeployScript().run());

        assertEq(leaf.lineMom(), dss.chainlog.getAddress("LINE_MOM"));
        assertEq(leaf.ilk(), ILK);
        assertEq(global.ilkRegistry(), dss.chainlog.getAddress("ILK_REGISTRY"));
        assertEq(global.lineMom(), dss.chainlog.getAddress("LINE_MOM"));
    }
}
