// SPDX-FileCopyrightText: © 2026 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {DssInstance, DssTest, MCD} from "dss-test/DssTest.sol";

import {LitePsmHaltSpellV2DeployScript} from "../../../script/lite-psm-halt/DeployLitePsmHaltV2.s.sol";
import {Flow, LitePsmHaltSpellV2} from "../../../src/lite-psm-halt/LitePsmHaltSpellV2.sol";

contract DeployLitePsmHaltV2IntegrationTest is DssTest {
    address internal constant CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;

    DssInstance internal dss;

    function setUp() public {
        vm.createSelectFork("mainnet");
        dss = MCD.loadFromChainlog(CHAINLOG);
    }

    function testNamedEntrypointsOnMainnet() public {
        address psm = dss.chainlog.getAddress("MCD_LITE_PSM_USDC_A");
        address mom = dss.chainlog.getAddress("LITE_PSM_MOM");
        LitePsmHaltSpellV2DeployScript deployer = new LitePsmHaltSpellV2DeployScript();
        LitePsmHaltSpellV2 sell = LitePsmHaltSpellV2(deployer.runSell(psm));
        LitePsmHaltSpellV2 buy = LitePsmHaltSpellV2(deployer.runBuy(psm));
        LitePsmHaltSpellV2 both = LitePsmHaltSpellV2(deployer.runBoth(psm));

        assertEq(sell.litePsmMom(), mom);
        assertEq(sell.psm(), psm);
        assertEq(uint256(sell.flow()), uint256(Flow.SELL));
        assertEq(uint256(buy.flow()), uint256(Flow.BUY));
        assertEq(uint256(both.flow()), uint256(Flow.BOTH));
    }
}
