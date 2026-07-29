// SPDX-FileCopyrightText: © 2026 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {Test} from "forge-std/Test.sol";

import {GlobalOsmStopSpellV2DeployScript, OsmStopSpellV2DeployScript} from "./DeployOsmStopV2.s.sol";
import {GlobalOsmStopSpellV2} from "../../src/osm-stop/GlobalOsmStopSpellV2.sol";
import {OsmStopSpellV2} from "../../src/osm-stop/OsmStopSpellV2.sol";

contract OsmMomDeployMockV2 {
    mapping(bytes32 => address) public osms;

    function setOsm(bytes32 ilk, address osm) external {
        osms[ilk] = osm;
    }
}

contract DeployOsmStopV2Test is Test {
    address internal constant CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;

    function setUp() public {
        _mockChainlog("MCD_PAUSE", address(1));
    }

    function testExplicitAndChainlogEntrypointsPinOsmMapping() public {
        OsmMomDeployMockV2 osmMom = new OsmMomDeployMockV2();
        address osm = address(0x32);
        address registry = address(0x33);
        bytes32 ilk = "ETH-A";
        _mockChainlog("OSM_MOM", address(osmMom));
        _mockChainlog("ILK_REGISTRY", registry);
        OsmStopSpellV2DeployScript deployer = new OsmStopSpellV2DeployScript();

        vm.expectRevert("OsmStopSpellV2DeployScript/osm-mismatch");
        deployer.run(address(osmMom), osm, ilk);
        osmMom.setOsm(ilk, osm);

        OsmStopSpellV2 explicitLeaf = OsmStopSpellV2(deployer.run(address(osmMom), osm, ilk));
        OsmStopSpellV2 chainlogLeaf = OsmStopSpellV2(deployer.run(osm, ilk));
        GlobalOsmStopSpellV2 global = GlobalOsmStopSpellV2(new GlobalOsmStopSpellV2DeployScript().run());

        assertEq(explicitLeaf.osmMom(), address(osmMom));
        assertEq(chainlogLeaf.osm(), osm);
        assertEq(chainlogLeaf.ilk(), ilk);
        assertEq(global.ilkRegistry(), registry);
        assertEq(global.osmMom(), address(osmMom));
    }

    function _mockChainlog(bytes32 key, address value) internal {
        vm.mockCall(CHAINLOG, abi.encodeWithSignature("getAddress(bytes32)", key), abi.encode(value));
    }
}
