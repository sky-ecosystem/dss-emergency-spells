// SPDX-FileCopyrightText: © 2026 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {Test} from "forge-std/Test.sol";

import {
    ClipBreakerSpellV2DeployScript,
    EmergencySpellBatchFactoryV2DeployScript,
    EmergencySpellBatchV2DeployScript,
    GlobalClipBreakerSpellV2DeployScript,
    OsmStopSpellV2DeployScript
} from "./DeployV2.s.sol";
import {EmergencySpellBatchV2} from "../src/EmergencySpellBatchV2.sol";
import {ClipBreakerSpellV2} from "../src/clip-breaker/ClipBreakerSpellV2.sol";
import {GlobalClipBreakerSpellV2} from "../src/clip-breaker/GlobalClipBreakerSpellV2.sol";
import {OsmStopSpellV2} from "../src/osm-stop/OsmStopSpellV2.sol";

contract OsmMomDeployMockV2 {
    mapping(bytes32 => address) public osms;

    function setOsm(bytes32 ilk, address osm) external {
        osms[ilk] = osm;
    }
}

contract DeployV2ScriptsTest is Test {
    address internal constant CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;
    bytes32 internal constant MCD_PAUSE = "MCD_PAUSE";

    function setUp() public {
        vm.mockCall(CHAINLOG, abi.encodeWithSignature("getAddress(bytes32)", MCD_PAUSE), abi.encode(address(0x1234)));
    }

    function testDeploysConcreteLeavesAndGlobalsDirectly() public {
        address clipperMom = address(0x1111);
        address clip = address(0x2222);
        bytes32 ilk = "ETH-A";
        address registry = address(0x3333);

        address leaf = new ClipBreakerSpellV2DeployScript().run(clipperMom, clip, ilk);
        address global = new GlobalClipBreakerSpellV2DeployScript().run(registry, clipperMom);

        assertEq(ClipBreakerSpellV2(leaf).clipperMom(), clipperMom);
        assertEq(ClipBreakerSpellV2(leaf).clip(), clip);
        assertEq(ClipBreakerSpellV2(leaf).ilk(), ilk);
        assertEq(GlobalClipBreakerSpellV2(global).ilkRegistry(), registry);
        assertEq(GlobalClipBreakerSpellV2(global).clipperMom(), clipperMom);
    }

    function testDeploysFactoryAndDeterministicBatch() public {
        address factory = new EmergencySpellBatchFactoryV2DeployScript().run();
        address[] memory leaves = new address[](2);
        leaves[0] = address(0x11);
        leaves[1] = address(0x22);

        EmergencySpellBatchV2DeployScript deployer = new EmergencySpellBatchV2DeployScript();
        bytes32 createConfigHash = keccak256(abi.encode(leaves, "Immediate incident batch"));
        bytes32 deterministicConfigHash = keccak256(abi.encode(leaves, "Incident batch"));
        address created = deployer.run(factory, leaves, "Immediate incident batch", createConfigHash);
        address predicted = deployer.preview(factory, leaves, "Incident batch");
        address batch = deployer.runDeterministic(factory, leaves, "Incident batch", deterministicConfigHash);

        assertEq(EmergencySpellBatchV2(created).leaves(), leaves);
        assertEq(batch, predicted);
        assertEq(EmergencySpellBatchV2(batch).leaves(), leaves);

        vm.expectRevert("EmergencySpellBatchV2DeployScript/config-hash-mismatch");
        deployer.run(factory, leaves, "Wrong config", deterministicConfigHash);
    }

    function testOsmDeploymentPinsCurrentMomMapping() public {
        OsmMomDeployMockV2 osmMom = new OsmMomDeployMockV2();
        address osm = address(0x4444);
        bytes32 ilk = "ETH-A";
        OsmStopSpellV2DeployScript deployer = new OsmStopSpellV2DeployScript();

        vm.expectRevert("OsmStopSpellV2DeployScript/osm-mismatch");
        deployer.run(address(osmMom), osm, ilk);

        osmMom.setOsm(ilk, osm);
        address deployed = deployer.run(address(osmMom), osm, ilk);
        assertEq(OsmStopSpellV2(deployed).osmMom(), address(osmMom));
        assertEq(OsmStopSpellV2(deployed).osm(), osm);
        assertEq(OsmStopSpellV2(deployed).ilk(), ilk);
    }
}
