// SPDX-FileCopyrightText: © 2026 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {DssInstance, DssTest, MCD} from "dss-test/DssTest.sol";

import {
    StUsdsRateSetterDissBudSpellV2DeployScript,
    StUsdsRateSetterHaltSpellV2DeployScript,
    StUsdsWipeParamSpellV2DeployScript
} from "../../../script/stusds/DeployStUsdsV2.s.sol";
import {StUsdsRateSetterDissBudSpellV2} from "../../../src/stusds/StUsdsRateSetterDissBudSpellV2.sol";
import {StUsdsRateSetterHaltSpellV2} from "../../../src/stusds/StUsdsRateSetterHaltSpellV2.sol";
import {Param, StUsdsWipeParamSpellV2} from "../../../src/stusds/StUsdsWipeParamSpellV2.sol";

contract DeployStUsdsV2IntegrationTest is DssTest {
    address internal constant CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;

    DssInstance internal dss;

    function setUp() public {
        vm.createSelectFork("mainnet");
        dss = MCD.loadFromChainlog(CHAINLOG);
    }

    function testChainlogEntrypointsOnMainnet() public {
        address mom = dss.chainlog.getAddress("STUSDS_MOM");
        address rateSetter = dss.chainlog.getAddress("STUSDS_RATE_SETTER");
        address stUsds = dss.chainlog.getAddress("STUSDS");
        address bud = makeAddr("bud");

        StUsdsRateSetterDissBudSpellV2 diss =
            StUsdsRateSetterDissBudSpellV2(new StUsdsRateSetterDissBudSpellV2DeployScript().run(bud));
        StUsdsRateSetterHaltSpellV2 halt =
            StUsdsRateSetterHaltSpellV2(new StUsdsRateSetterHaltSpellV2DeployScript().run());
        StUsdsWipeParamSpellV2DeployScript wipeDeployer = new StUsdsWipeParamSpellV2DeployScript();
        StUsdsWipeParamSpellV2 cap = StUsdsWipeParamSpellV2(wipeDeployer.runCap());
        StUsdsWipeParamSpellV2 line = StUsdsWipeParamSpellV2(wipeDeployer.runLine());
        StUsdsWipeParamSpellV2 both = StUsdsWipeParamSpellV2(wipeDeployer.runBoth());

        assertEq(diss.stUsdsMom(), mom);
        assertEq(diss.rateSetter(), rateSetter);
        assertEq(diss.bud(), bud);
        assertEq(halt.stUsdsMom(), mom);
        assertEq(cap.stUsds(), stUsds);
        assertEq(uint256(cap.param()), uint256(Param.CAP));
        assertEq(uint256(line.param()), uint256(Param.LINE));
        assertEq(uint256(both.param()), uint256(Param.BOTH));
    }
}
