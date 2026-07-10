// SPDX-FileCopyrightText: © 2026 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {DssInstance, DssTest, MCD} from "dss-test/DssTest.sol";

import {ClipBreakerSpellV2DeployScript, GlobalClipBreakerSpellV2DeployScript} from "./DeployClipBreakerV2.s.sol";
import {ClipBreakerSpellV2} from "../../src/clip-breaker/ClipBreakerSpellV2.sol";
import {GlobalClipBreakerSpellV2} from "../../src/clip-breaker/GlobalClipBreakerSpellV2.sol";

interface IlkRegistryForClipDeploy {
    function xlip(bytes32 ilk) external view returns (address);
}

contract DeployClipBreakerV2IntegrationTest is DssTest {
    address internal constant CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;
    bytes32 internal constant ILK = "ETH-A";

    DssInstance internal dss;

    function setUp() public {
        vm.createSelectFork("mainnet");
        dss = MCD.loadFromChainlog(CHAINLOG);
    }

    function testChainlogEntrypointsOnMainnet() public {
        address registry = dss.chainlog.getAddress("ILK_REGISTRY");
        address clip = IlkRegistryForClipDeploy(registry).xlip(ILK);
        ClipBreakerSpellV2 leaf = ClipBreakerSpellV2(new ClipBreakerSpellV2DeployScript().run(clip, ILK));
        GlobalClipBreakerSpellV2 global = GlobalClipBreakerSpellV2(new GlobalClipBreakerSpellV2DeployScript().run());

        assertEq(leaf.clipperMom(), dss.chainlog.getAddress("CLIPPER_MOM"));
        assertEq(leaf.clip(), clip);
        assertEq(leaf.ilk(), ILK);
        assertEq(global.ilkRegistry(), registry);
        assertEq(global.clipperMom(), dss.chainlog.getAddress("CLIPPER_MOM"));
    }
}
