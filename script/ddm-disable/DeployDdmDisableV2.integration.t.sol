// SPDX-FileCopyrightText: © 2026 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {DssInstance, DssTest, MCD} from "dss-test/DssTest.sol";

import {DdmDisableSpellV2DeployScript} from "./DeployDdmDisableV2.s.sol";
import {DdmDisableSpellV2} from "../../src/ddm-disable/DdmDisableSpellV2.sol";

interface DdmHubForDeploy {
    function plan(bytes32 ilk) external view returns (address);
}

contract DeployDdmDisableV2IntegrationTest is DssTest {
    address internal constant CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;
    bytes32 internal constant ILK = "DIRECT-SPARK-DAI";

    DssInstance internal dss;

    function setUp() public {
        vm.createSelectFork("mainnet");
        dss = MCD.loadFromChainlog(CHAINLOG);
    }

    function testChainlogEntrypointOnMainnet() public {
        address plan = DdmHubForDeploy(dss.chainlog.getAddress("DIRECT_HUB")).plan(ILK);
        DdmDisableSpellV2 spell = DdmDisableSpellV2(new DdmDisableSpellV2DeployScript().run(plan, ILK));

        assertEq(spell.ddmMom(), dss.chainlog.getAddress("DIRECT_MOM"));
        assertEq(spell.plan(), plan);
        assertEq(spell.ilk(), ILK);
    }
}
