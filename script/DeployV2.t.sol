// SPDX-FileCopyrightText: © 2026 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {Test} from "forge-std/Test.sol";

import {
    ClipBreakerSpellV2DeployScript,
    DdmDisableSpellV2DeployScript,
    EmergencySpellBatchFactoryV2DeployScript,
    EmergencySpellBatchV2DeployScript,
    GlobalClipBreakerSpellV2DeployScript,
    GlobalLineWipeSpellV2DeployScript,
    GlobalOsmStopSpellV2DeployScript,
    LineWipeSpellV2DeployScript,
    LitePsmHaltSpellV2DeployScript,
    OsmStopSpellV2DeployScript,
    SPBEAMHaltSpellV2DeployScript,
    SplitterStopSpellV2DeployScript,
    StUsdsRateSetterDissBudSpellV2DeployScript,
    StUsdsRateSetterHaltSpellV2DeployScript,
    StUsdsWipeParamSpellV2DeployScript
} from "./DeployV2.s.sol";
import {EmergencySpellBatchV2} from "../src/EmergencySpellBatchV2.sol";
import {ClipBreakerSpellV2} from "../src/clip-breaker/ClipBreakerSpellV2.sol";
import {GlobalClipBreakerSpellV2} from "../src/clip-breaker/GlobalClipBreakerSpellV2.sol";
import {DdmDisableSpellV2} from "../src/ddm-disable/DdmDisableSpellV2.sol";
import {GlobalLineWipeSpellV2} from "../src/line-wipe/GlobalLineWipeSpellV2.sol";
import {LineWipeSpellV2} from "../src/line-wipe/LineWipeSpellV2.sol";
import {Flow, LitePsmHaltSpellV2} from "../src/lite-psm-halt/LitePsmHaltSpellV2.sol";
import {GlobalOsmStopSpellV2} from "../src/osm-stop/GlobalOsmStopSpellV2.sol";
import {OsmStopSpellV2} from "../src/osm-stop/OsmStopSpellV2.sol";
import {SPBEAMHaltSpellV2} from "../src/spbeam-halt/SPBEAMHaltSpellV2.sol";
import {SplitterStopSpellV2} from "../src/splitter-stop/SplitterStopSpellV2.sol";
import {StUsdsRateSetterDissBudSpellV2} from "../src/stusds/StUsdsRateSetterDissBudSpellV2.sol";
import {StUsdsRateSetterHaltSpellV2} from "../src/stusds/StUsdsRateSetterHaltSpellV2.sol";
import {Param, StUsdsWipeParamSpellV2} from "../src/stusds/StUsdsWipeParamSpellV2.sol";

contract OsmMomDeployMockV2 {
    mapping(bytes32 => address) public osms;

    function setOsm(bytes32 ilk, address osm) external {
        osms[ilk] = osm;
    }
}

contract DeployV2ScriptsTest is Test {
    address internal constant CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;
    bytes32 internal constant CLIPPER_MOM = "CLIPPER_MOM";
    bytes32 internal constant DIRECT_MOM = "DIRECT_MOM";
    bytes32 internal constant EMERGENCY_SPELL_BATCH_FAB = "EMERGENCY_SPELL_BATCH_FAB";
    bytes32 internal constant ILK_REGISTRY = "ILK_REGISTRY";
    bytes32 internal constant LINE_MOM = "LINE_MOM";
    bytes32 internal constant LITE_PSM_ILK = "LITE-PSM";
    bytes32 internal constant LITE_PSM_MOM = "LITE_PSM_MOM";
    bytes32 internal constant MCD_SPBEAM = "MCD_SPBEAM";
    bytes32 internal constant MCD_SPLIT = "MCD_SPLIT";
    bytes32 internal constant MCD_PAUSE = "MCD_PAUSE";
    bytes32 internal constant MCD_VAT = "MCD_VAT";
    bytes32 internal constant OSM_MOM = "OSM_MOM";
    bytes32 internal constant SPBEAM_MOM = "SPBEAM_MOM";
    bytes32 internal constant SPLITTER_MOM = "SPLITTER_MOM";
    bytes32 internal constant STUSDS = "STUSDS";
    bytes32 internal constant STUSDS_ILK = "STUSDS";
    bytes32 internal constant STUSDS_MOM = "STUSDS_MOM";
    bytes32 internal constant STUSDS_RATE_SETTER = "STUSDS_RATE_SETTER";

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

    function testChainlogBackedCoreLeavesKeepSubjectsExplicit() public {
        address lineMom = address(0x1001);
        address autoLine = address(0x1002);
        address vat = address(0x1003);
        address clipperMom = address(0x2001);
        address clip = address(0x2002);
        OsmMomDeployMockV2 osmMom = new OsmMomDeployMockV2();
        address osm = address(0x3002);
        address ddmMom = address(0x4001);
        address plan = address(0x4002);
        bytes32 ilk = "ETH-A";

        _mockChainlog(LINE_MOM, lineMom);
        _mockChainlog(MCD_VAT, vat);
        _mockChainlog(CLIPPER_MOM, clipperMom);
        _mockChainlog(OSM_MOM, address(osmMom));
        _mockChainlog(DIRECT_MOM, ddmMom);
        vm.mockCall(lineMom, abi.encodeWithSignature("autoLine()"), abi.encode(autoLine));
        osmMom.setOsm(ilk, osm);

        LineWipeSpellV2 line = LineWipeSpellV2(new LineWipeSpellV2DeployScript().run(ilk));
        ClipBreakerSpellV2 clipBreaker = ClipBreakerSpellV2(new ClipBreakerSpellV2DeployScript().run(clip, ilk));
        OsmStopSpellV2 osmStop = OsmStopSpellV2(new OsmStopSpellV2DeployScript().run(osm, ilk));
        DdmDisableSpellV2 ddm = DdmDisableSpellV2(new DdmDisableSpellV2DeployScript().run(plan, ilk));

        assertEq(line.lineMom(), lineMom);
        assertEq(line.ilk(), ilk);
        assertEq(clipBreaker.clipperMom(), clipperMom);
        assertEq(clipBreaker.clip(), clip);
        assertEq(osmStop.osmMom(), address(osmMom));
        assertEq(osmStop.osm(), osm);
        assertEq(ddm.ddmMom(), ddmMom);
        assertEq(ddm.plan(), plan);
    }

    function testChainlogBackedLitePsmNamedEntrypoints() public {
        address litePsmMom = address(0x5001);
        address psm = address(0x5002);
        _mockChainlog(LITE_PSM_MOM, litePsmMom);
        vm.mockCall(psm, abi.encodeWithSignature("ilk()"), abi.encode(LITE_PSM_ILK));

        LitePsmHaltSpellV2DeployScript deployer = new LitePsmHaltSpellV2DeployScript();
        LitePsmHaltSpellV2 sell = LitePsmHaltSpellV2(deployer.runSell(psm));
        LitePsmHaltSpellV2 buy = LitePsmHaltSpellV2(deployer.runBuy(psm));
        LitePsmHaltSpellV2 both = LitePsmHaltSpellV2(deployer.runBoth(psm));

        assertEq(sell.litePsmMom(), litePsmMom);
        assertEq(sell.psm(), psm);
        assertEq(uint256(sell.flow()), uint256(Flow.SELL));
        assertEq(uint256(buy.flow()), uint256(Flow.BUY));
        assertEq(uint256(both.flow()), uint256(Flow.BOTH));
    }

    function testChainlogBackedStandaloneEntrypoints() public {
        address spbeamMom = address(0x6001);
        address spbeam = address(0x6002);
        address splitterMom = address(0x7001);
        address splitter = address(0x7002);

        _mockChainlog(SPBEAM_MOM, spbeamMom);
        _mockChainlog(MCD_SPBEAM, spbeam);
        _mockChainlog(SPLITTER_MOM, splitterMom);
        _mockChainlog(MCD_SPLIT, splitter);
        vm.mockCall(splitterMom, abi.encodeWithSignature("splitter()"), abi.encode(splitter));

        SPBEAMHaltSpellV2 spbeamSpell = SPBEAMHaltSpellV2(new SPBEAMHaltSpellV2DeployScript().run());
        SplitterStopSpellV2 splitterSpell = SplitterStopSpellV2(new SplitterStopSpellV2DeployScript().run());

        assertEq(spbeamSpell.spbeamMom(), spbeamMom);
        assertEq(spbeamSpell.spbeam(), spbeam);
        assertEq(splitterSpell.splitterMom(), splitterMom);
        assertEq(splitterSpell.splitter(), splitter);
    }

    function testChainlogBackedStUsdsRateSetterEntrypoints() public {
        address stUsdsMom = address(0x8001);
        address rateSetter = address(0x8002);
        address stUsds = address(0x8003);
        address bud = address(0x8005);
        _mockChainlog(STUSDS_MOM, stUsdsMom);
        _mockChainlog(STUSDS_RATE_SETTER, rateSetter);
        vm.mockCall(stUsdsMom, abi.encodeWithSignature("stusds()"), abi.encode(stUsds));
        vm.mockCall(rateSetter, abi.encodeWithSignature("stusds()"), abi.encode(stUsds));

        StUsdsRateSetterDissBudSpellV2 diss =
            StUsdsRateSetterDissBudSpellV2(new StUsdsRateSetterDissBudSpellV2DeployScript().run(bud));
        StUsdsRateSetterHaltSpellV2 halt =
            StUsdsRateSetterHaltSpellV2(new StUsdsRateSetterHaltSpellV2DeployScript().run());

        assertEq(diss.stUsdsMom(), stUsdsMom);
        assertEq(diss.rateSetter(), rateSetter);
        assertEq(diss.bud(), bud);
        assertEq(halt.stUsdsMom(), stUsdsMom);
        assertEq(halt.rateSetter(), rateSetter);
    }

    function testChainlogBackedStUsdsWipeNamedEntrypoints() public {
        address stUsdsMom = address(0x8001);
        address rateSetter = address(0x8002);
        address stUsds = address(0x8003);
        address vat = address(0x8004);
        _mockChainlog(STUSDS_MOM, stUsdsMom);
        _mockChainlog(STUSDS_RATE_SETTER, rateSetter);
        _mockChainlog(STUSDS, stUsds);
        _mockChainlog(MCD_VAT, vat);
        vm.mockCall(stUsdsMom, abi.encodeWithSignature("stusds()"), abi.encode(stUsds));
        vm.mockCall(rateSetter, abi.encodeWithSignature("stusds()"), abi.encode(stUsds));
        vm.mockCall(stUsds, abi.encodeWithSignature("ilk()"), abi.encode(STUSDS_ILK));

        StUsdsWipeParamSpellV2DeployScript wipeDeployer = new StUsdsWipeParamSpellV2DeployScript();
        StUsdsWipeParamSpellV2 cap = StUsdsWipeParamSpellV2(wipeDeployer.runCap());
        StUsdsWipeParamSpellV2 line = StUsdsWipeParamSpellV2(wipeDeployer.runLine());
        StUsdsWipeParamSpellV2 both = StUsdsWipeParamSpellV2(wipeDeployer.runBoth());

        assertEq(uint256(cap.param()), uint256(Param.CAP));
        assertEq(uint256(line.param()), uint256(Param.LINE));
        assertEq(uint256(both.param()), uint256(Param.BOTH));
    }

    function testChainlogBackedGlobals() public {
        address registry = address(0x9001);
        address lineMom = address(0x9002);
        address autoLine = address(0x9003);
        address vat = address(0x9004);
        address clipperMom = address(0x9005);
        address osmMom = address(0x9006);
        _mockChainlog(ILK_REGISTRY, registry);
        _mockChainlog(LINE_MOM, lineMom);
        _mockChainlog(MCD_VAT, vat);
        _mockChainlog(CLIPPER_MOM, clipperMom);
        _mockChainlog(OSM_MOM, osmMom);
        vm.mockCall(lineMom, abi.encodeWithSignature("autoLine()"), abi.encode(autoLine));

        GlobalLineWipeSpellV2 line = GlobalLineWipeSpellV2(new GlobalLineWipeSpellV2DeployScript().run());
        GlobalClipBreakerSpellV2 clip = GlobalClipBreakerSpellV2(new GlobalClipBreakerSpellV2DeployScript().run());
        GlobalOsmStopSpellV2 osm = GlobalOsmStopSpellV2(new GlobalOsmStopSpellV2DeployScript().run());

        assertEq(line.ilkRegistry(), registry);
        assertEq(line.lineMom(), lineMom);
        assertEq(clip.ilkRegistry(), registry);
        assertEq(clip.clipperMom(), clipperMom);
        assertEq(osm.ilkRegistry(), registry);
        assertEq(osm.osmMom(), osmMom);
    }

    function testChainlogBackedBatchFactoryLookup() public {
        address factory = new EmergencySpellBatchFactoryV2DeployScript().run();
        _mockChainlog(EMERGENCY_SPELL_BATCH_FAB, factory);
        address[] memory leaves = new address[](2);
        leaves[0] = address(0x11);
        leaves[1] = address(0x22);
        EmergencySpellBatchV2DeployScript deployer = new EmergencySpellBatchV2DeployScript();
        bytes32 createHash = keccak256(abi.encode(leaves, "Create"));
        bytes32 create2Hash = keccak256(abi.encode(leaves, "Create2"));

        address created = deployer.run(leaves, "Create", createHash);
        address predicted = deployer.preview(leaves, "Create2");
        address deterministic = deployer.runDeterministic(leaves, "Create2", create2Hash);

        assertEq(EmergencySpellBatchV2(created).leaves(), leaves);
        assertEq(deterministic, predicted);
    }

    function _mockChainlog(bytes32 key, address value) internal {
        vm.mockCall(CHAINLOG, abi.encodeWithSignature("getAddress(bytes32)", key), abi.encode(value));
    }
}
