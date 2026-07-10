// SPDX-FileCopyrightText: © 2026 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {DssInstance, DssTest, MCD} from "dss-test/DssTest.sol";

import {GlobalOsmStopSpellV2DeployScript, OsmStopSpellV2DeployScript} from "./DeployOsmStopV2.s.sol";
import {GlobalOsmStopSpellV2} from "../../src/osm-stop/GlobalOsmStopSpellV2.sol";
import {OsmStopSpellV2} from "../../src/osm-stop/OsmStopSpellV2.sol";

interface OsmMomForDeploy {
    function osms(bytes32 ilk) external view returns (address);
}

contract DeployOsmStopV2IntegrationTest is DssTest {
    address internal constant CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;
    bytes32 internal constant ILK = "ETH-A";

    DssInstance internal dss;

    function setUp() public {
        vm.createSelectFork("mainnet");
        dss = MCD.loadFromChainlog(CHAINLOG);
    }

    function testChainlogEntrypointsOnMainnet() public {
        address osmMom = dss.chainlog.getAddress("OSM_MOM");
        address osm = OsmMomForDeploy(osmMom).osms(ILK);
        OsmStopSpellV2 leaf = OsmStopSpellV2(new OsmStopSpellV2DeployScript().run(osm, ILK));
        GlobalOsmStopSpellV2 global = GlobalOsmStopSpellV2(new GlobalOsmStopSpellV2DeployScript().run());

        assertEq(leaf.osmMom(), osmMom);
        assertEq(leaf.osm(), osm);
        assertEq(leaf.ilk(), ILK);
        assertEq(global.ilkRegistry(), dss.chainlog.getAddress("ILK_REGISTRY"));
        assertEq(global.osmMom(), osmMom);
    }
}
