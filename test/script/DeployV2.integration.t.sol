// SPDX-FileCopyrightText: © 2026 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {DssInstance, DssTest, MCD} from "dss-test/DssTest.sol";

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
} from "../../script/DeployV2.s.sol";
import {EmergencySpellBatchV2} from "../../src/EmergencySpellBatchV2.sol";
import {ClipBreakerSpellV2} from "../../src/clip-breaker/ClipBreakerSpellV2.sol";
import {GlobalClipBreakerSpellV2} from "../../src/clip-breaker/GlobalClipBreakerSpellV2.sol";
import {DdmDisableSpellV2} from "../../src/ddm-disable/DdmDisableSpellV2.sol";
import {GlobalLineWipeSpellV2} from "../../src/line-wipe/GlobalLineWipeSpellV2.sol";
import {LineWipeSpellV2} from "../../src/line-wipe/LineWipeSpellV2.sol";
import {Flow, LitePsmHaltSpellV2} from "../../src/lite-psm-halt/LitePsmHaltSpellV2.sol";
import {GlobalOsmStopSpellV2} from "../../src/osm-stop/GlobalOsmStopSpellV2.sol";
import {OsmStopSpellV2} from "../../src/osm-stop/OsmStopSpellV2.sol";
import {SPBEAMHaltSpellV2} from "../../src/spbeam-halt/SPBEAMHaltSpellV2.sol";
import {SplitterStopSpellV2} from "../../src/splitter-stop/SplitterStopSpellV2.sol";
import {StUsdsRateSetterDissBudSpellV2} from "../../src/stusds/StUsdsRateSetterDissBudSpellV2.sol";
import {StUsdsRateSetterHaltSpellV2} from "../../src/stusds/StUsdsRateSetterHaltSpellV2.sol";
import {Param, StUsdsWipeParamSpellV2} from "../../src/stusds/StUsdsWipeParamSpellV2.sol";

interface IlkRegistryForDeployScripts {
    function xlip(bytes32 ilk) external view returns (address);
}

interface OsmMomForDeployScripts {
    function osms(bytes32 ilk) external view returns (address);
}

interface DdmHubForDeployScripts {
    function plan(bytes32 ilk) external view returns (address);
}

contract DeployV2ScriptsIntegrationTest is DssTest {
    address internal constant CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;
    bytes32 internal constant EMERGENCY_SPELL_BATCH_FAB = "EMERGENCY_SPELL_BATCH_FAB";
    bytes32 internal constant ILK = "ETH-A";

    DssInstance internal dss;

    function setUp() public {
        vm.createSelectFork("mainnet");
        dss = MCD.loadFromChainlog(CHAINLOG);
    }

    function testCoreConvenienceEntrypointsUseLiveChainlogDependencies() public {
        address lineMom = dss.chainlog.getAddress("LINE_MOM");
        LineWipeSpellV2 line = LineWipeSpellV2(new LineWipeSpellV2DeployScript().run(ILK));
        assertEq(line.lineMom(), lineMom);
        assertEq(line.ilk(), ILK);

        address clipperMom = dss.chainlog.getAddress("CLIPPER_MOM");
        address clip = IlkRegistryForDeployScripts(dss.chainlog.getAddress("ILK_REGISTRY")).xlip(ILK);
        ClipBreakerSpellV2 breaker = ClipBreakerSpellV2(new ClipBreakerSpellV2DeployScript().run(clip, ILK));
        assertEq(breaker.clipperMom(), clipperMom);
        assertEq(breaker.clip(), clip);
        assertEq(breaker.ilk(), ILK);
    }

    function testOsmAndDdmConvenienceEntrypointsKeepLiveSubjectsExplicit() public {
        address osmMom = dss.chainlog.getAddress("OSM_MOM");
        address osm = OsmMomForDeployScripts(osmMom).osms(ILK);
        OsmStopSpellV2 osmStop = OsmStopSpellV2(new OsmStopSpellV2DeployScript().run(osm, ILK));
        assertEq(osmStop.osmMom(), osmMom);
        assertEq(osmStop.osm(), osm);

        bytes32 ddmIlk = "DIRECT-SPARK-DAI";
        address ddmMom = dss.chainlog.getAddress("DIRECT_MOM");
        address plan = DdmHubForDeployScripts(dss.chainlog.getAddress("DIRECT_HUB")).plan(ddmIlk);
        DdmDisableSpellV2 ddm = DdmDisableSpellV2(new DdmDisableSpellV2DeployScript().run(plan, ddmIlk));
        assertEq(ddm.ddmMom(), ddmMom);
        assertEq(ddm.plan(), plan);
        assertEq(ddm.ilk(), ddmIlk);
    }

    function testLitePsmNamedEntrypointsUseLiveMom() public {
        address litePsmMom = dss.chainlog.getAddress("LITE_PSM_MOM");
        address psm = dss.chainlog.getAddress("MCD_LITE_PSM_USDC_A");
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

    function testStandaloneConvenienceEntrypointsUseLiveChainlogDependencies() public {
        SPBEAMHaltSpellV2 spbeam = SPBEAMHaltSpellV2(new SPBEAMHaltSpellV2DeployScript().run());
        assertEq(spbeam.spbeamMom(), dss.chainlog.getAddress("SPBEAM_MOM"));
        assertEq(spbeam.spbeam(), dss.chainlog.getAddress("MCD_SPBEAM"));

        SplitterStopSpellV2 splitter = SplitterStopSpellV2(new SplitterStopSpellV2DeployScript().run());
        assertEq(splitter.splitterMom(), dss.chainlog.getAddress("SPLITTER_MOM"));
        assertEq(splitter.splitter(), dss.chainlog.getAddress("MCD_SPLIT"));
    }

    function testStUsdsConvenienceEntrypointsUseLiveChainlogDependencies() public {
        address stUsdsMom = dss.chainlog.getAddress("STUSDS_MOM");
        address rateSetter = dss.chainlog.getAddress("STUSDS_RATE_SETTER");
        address stUsds = dss.chainlog.getAddress("STUSDS");
        address bud = makeAddr("bud");

        StUsdsRateSetterDissBudSpellV2 diss =
            StUsdsRateSetterDissBudSpellV2(new StUsdsRateSetterDissBudSpellV2DeployScript().run(bud));
        StUsdsRateSetterHaltSpellV2 halt =
            StUsdsRateSetterHaltSpellV2(new StUsdsRateSetterHaltSpellV2DeployScript().run());
        assertEq(diss.stUsdsMom(), stUsdsMom);
        assertEq(diss.rateSetter(), rateSetter);
        assertEq(diss.bud(), bud);
        assertEq(halt.stUsdsMom(), stUsdsMom);
        assertEq(halt.rateSetter(), rateSetter);

        StUsdsWipeParamSpellV2DeployScript wipeDeployer = new StUsdsWipeParamSpellV2DeployScript();
        StUsdsWipeParamSpellV2 cap = StUsdsWipeParamSpellV2(wipeDeployer.runCap());
        StUsdsWipeParamSpellV2 line = StUsdsWipeParamSpellV2(wipeDeployer.runLine());
        StUsdsWipeParamSpellV2 both = StUsdsWipeParamSpellV2(wipeDeployer.runBoth());
        assertEq(cap.stUsds(), stUsds);
        assertEq(uint256(cap.param()), uint256(Param.CAP));
        assertEq(uint256(line.param()), uint256(Param.LINE));
        assertEq(uint256(both.param()), uint256(Param.BOTH));
    }

    function testGlobalConvenienceEntrypointsUseLiveChainlogDependencies() public {
        address registry = dss.chainlog.getAddress("ILK_REGISTRY");
        GlobalLineWipeSpellV2 line = GlobalLineWipeSpellV2(new GlobalLineWipeSpellV2DeployScript().run());
        GlobalClipBreakerSpellV2 clip = GlobalClipBreakerSpellV2(new GlobalClipBreakerSpellV2DeployScript().run());
        GlobalOsmStopSpellV2 osm = GlobalOsmStopSpellV2(new GlobalOsmStopSpellV2DeployScript().run());

        assertEq(line.ilkRegistry(), registry);
        assertEq(line.lineMom(), dss.chainlog.getAddress("LINE_MOM"));
        assertEq(clip.ilkRegistry(), registry);
        assertEq(clip.clipperMom(), dss.chainlog.getAddress("CLIPPER_MOM"));
        assertEq(osm.ilkRegistry(), registry);
        assertEq(osm.osmMom(), dss.chainlog.getAddress("OSM_MOM"));
    }

    function testBatchConvenienceEntrypointsUsePlannedFactoryKey() public {
        address factory = new EmergencySpellBatchFactoryV2DeployScript().run();
        vm.mockCall(
            CHAINLOG, abi.encodeWithSignature("getAddress(bytes32)", EMERGENCY_SPELL_BATCH_FAB), abi.encode(factory)
        );
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
}
