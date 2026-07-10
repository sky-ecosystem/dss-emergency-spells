// SPDX-FileCopyrightText: © 2026 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {Test} from "forge-std/Test.sol";

import {ClipBreakerSpellV2} from "./clip-breaker/ClipBreakerSpellV2.sol";
import {DdmDisableSpellV2} from "./ddm-disable/DdmDisableSpellV2.sol";
import {EmergencySpellBatchV2} from "./EmergencySpellBatchV2.sol";
import {LineWipeSpellV2} from "./line-wipe/LineWipeSpellV2.sol";
import {Flow, LitePsmHaltSpellV2} from "./lite-psm-halt/LitePsmHaltSpellV2.sol";
import {OsmStopSpellV2} from "./osm-stop/OsmStopSpellV2.sol";

contract VatStateMockV2 {
    mapping(bytes32 => uint256) public line;

    function setLine(bytes32 ilk, uint256 line_) external {
        line[ilk] = line_;
    }

    function wipe(bytes32 ilk) external {
        line[ilk] = 0;
    }

    function ilks(bytes32 ilk)
        external
        view
        returns (uint256 Art, uint256 rate, uint256 spot, uint256 line_, uint256 dust)
    {
        return (0, 0, 0, line[ilk], 0);
    }
}

contract AutoLineStateMockV2 {
    struct Config {
        uint256 maxLine;
        uint256 gap;
        uint48 ttl;
        uint48 last;
        uint48 lastInc;
    }

    mapping(bytes32 => Config) internal configs;

    function set(bytes32 ilk, uint256 maxLine, uint256 gap, uint48 ttl, uint48 last, uint48 lastInc) external {
        configs[ilk] = Config(maxLine, gap, ttl, last, lastInc);
    }

    function wipe(bytes32 ilk) external {
        delete configs[ilk];
    }

    function ilks(bytes32 ilk)
        external
        view
        returns (uint256 maxLine, uint256 gap, uint48 ttl, uint48 last, uint48 lastInc)
    {
        Config memory config = configs[ilk];
        return (config.maxLine, config.gap, config.ttl, config.last, config.lastInc);
    }
}

contract LineMomMockV2 {
    address public immutable autoLine;
    AutoLineStateMockV2 internal immutable _autoLine;
    VatStateMockV2 internal immutable _vat;
    mapping(address => bool) public authorized;
    address public lastCaller;

    constructor(address autoLine_, address vat_) {
        autoLine = autoLine_;
        _autoLine = AutoLineStateMockV2(autoLine_);
        _vat = VatStateMockV2(vat_);
    }

    function rely(address caller) external {
        authorized[caller] = true;
    }

    function wipe(bytes32 ilk) external returns (uint256) {
        require(authorized[msg.sender], "LineMom/not-authorized");
        lastCaller = msg.sender;
        _autoLine.wipe(ilk);
        _vat.wipe(ilk);
        return 0;
    }
}

contract BrokenLineMomMockV2 {
    address public immutable autoLine;

    constructor(address autoLine_) {
        autoLine = autoLine_;
    }
}

contract ClipMockV2 {
    uint256 public stopped;

    function setStopped(uint256 stopped_) external {
        stopped = stopped_;
    }
}

contract ClipperMomMockV2 {
    mapping(address => bool) public authorized;
    address public lastCaller;

    function rely(address caller) external {
        authorized[caller] = true;
    }

    function setBreaker(address clip, uint256 level, uint256) external {
        require(authorized[msg.sender], "ClipperMom/not-authorized");
        lastCaller = msg.sender;
        ClipMockV2(clip).setStopped(level);
    }
}

contract OsmMockV2 {
    uint256 public stopped;

    function stop() external {
        stopped = 1;
    }
}

contract OsmMomMockV2 {
    mapping(bytes32 => address) public osms;
    mapping(address => bool) public authorized;
    address public lastCaller;

    function rely(address caller) external {
        authorized[caller] = true;
    }

    function setOsm(bytes32 ilk, address osm) external {
        osms[ilk] = osm;
    }

    function stop(bytes32 ilk) external {
        require(authorized[msg.sender], "OsmMom/not-authorized");
        lastCaller = msg.sender;
        OsmMockV2(osms[ilk]).stop();
    }
}

contract DdmPlanMockV2 {
    bool public active = true;

    function disable() external {
        active = false;
    }
}

contract DdmMomMockV2 {
    mapping(address => bool) public authorized;
    address public lastCaller;

    function rely(address caller) external {
        authorized[caller] = true;
    }

    function disable(address plan) external {
        require(authorized[msg.sender], "DdmMom/not-authorized");
        lastCaller = msg.sender;
        DdmPlanMockV2(plan).disable();
    }
}

contract LitePsmMockV2 {
    bytes32 public immutable ilk;
    uint256 public immutable HALTED = type(uint256).max;
    uint256 public tin = 1;
    uint256 public tout = 2;

    constructor(bytes32 ilk_) {
        ilk = ilk_;
    }

    function halt(Flow flow) external {
        if (flow == Flow.SELL || flow == Flow.BOTH) tin = HALTED;
        if (flow == Flow.BUY || flow == Flow.BOTH) tout = HALTED;
    }
}

contract LitePsmMomMockV2 {
    mapping(address => bool) public authorized;
    address public lastCaller;

    function rely(address caller) external {
        authorized[caller] = true;
    }

    function halt(address psm, Flow flow) external {
        require(authorized[msg.sender], "LitePsmMom/not-authorized");
        lastCaller = msg.sender;
        LitePsmMockV2(psm).halt(flow);
    }
}

contract ContractWithoutLeafInterfaceV2 {}

contract CoreLeavesV2Test is Test {
    address internal constant CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;
    bytes32 internal constant MCD_PAUSE = "MCD_PAUSE";
    bytes32 internal constant MCD_VAT = "MCD_VAT";
    bytes32 internal constant ILK = "ETH-A";

    ContractWithoutLeafInterfaceV2 internal pause;
    VatStateMockV2 internal vat;
    AutoLineStateMockV2 internal autoLine;
    LineMomMockV2 internal lineMom;
    ClipMockV2 internal clip;
    ClipperMomMockV2 internal clipperMom;
    OsmMockV2 internal osm;
    OsmMomMockV2 internal osmMom;
    DdmPlanMockV2 internal ddmPlan;
    DdmMomMockV2 internal ddmMom;
    LitePsmMockV2 internal litePsm;
    LitePsmMomMockV2 internal litePsmMom;

    LineWipeSpellV2 internal lineSpell;
    ClipBreakerSpellV2 internal clipSpell;
    OsmStopSpellV2 internal osmSpell;
    DdmDisableSpellV2 internal ddmSpell;
    LitePsmHaltSpellV2 internal litePsmSpell;

    function setUp() public {
        pause = new ContractWithoutLeafInterfaceV2();
        vat = new VatStateMockV2();
        vm.mockCall(CHAINLOG, abi.encodeWithSignature("getAddress(bytes32)", MCD_PAUSE), abi.encode(address(pause)));
        vm.mockCall(CHAINLOG, abi.encodeWithSignature("getAddress(bytes32)", MCD_VAT), abi.encode(address(vat)));

        autoLine = new AutoLineStateMockV2();
        lineMom = new LineMomMockV2(address(autoLine), address(vat));
        vat.setLine(ILK, 100);
        autoLine.set(ILK, 200, 50, 1 hours, 10, 11);

        clip = new ClipMockV2();
        clipperMom = new ClipperMomMockV2();

        osm = new OsmMockV2();
        osmMom = new OsmMomMockV2();
        osmMom.setOsm(ILK, address(osm));

        ddmPlan = new DdmPlanMockV2();
        ddmMom = new DdmMomMockV2();

        litePsm = new LitePsmMockV2("LITE-PSM-USDC-A");
        litePsmMom = new LitePsmMomMockV2();

        lineSpell = new LineWipeSpellV2(address(lineMom), ILK);
        clipSpell = new ClipBreakerSpellV2(address(clipperMom), address(clip), ILK);
        osmSpell = new OsmStopSpellV2(address(osmMom), address(osm), ILK);
        ddmSpell = new DdmDisableSpellV2(address(ddmMom), address(ddmPlan), "DIRECT-SPARK-DAI");
        litePsmSpell = new LitePsmHaltSpellV2(address(litePsmMom), address(litePsm), Flow.BOTH);
    }

    function testDescriptionsIdentifyExplicitSubjects() public view {
        assertEq(lineSpell.description(), string(abi.encodePacked("Emergency Spell | Line Wipe: ", ILK)));
        assertEq(clipSpell.description(), string(abi.encodePacked("Emergency Spell | Set Clip Breaker: ", ILK)));
        assertEq(osmSpell.description(), string(abi.encodePacked("Emergency Spell | OSM Stop: ", ILK)));
        assertEq(
            ddmSpell.description(), string(abi.encodePacked("Emergency Spell | Disable DDM Plan: ", ddmSpell.ilk()))
        );
        assertEq(
            litePsmSpell.description(),
            string(abi.encodePacked("Emergency Spell | ", litePsmSpell.ilk(), " | halt: BOTH"))
        );
    }

    function testDoneReportsOnlyEmergencyEndState() public view {
        assertFalse(lineSpell.done());
        assertFalse(clipSpell.done());
        assertFalse(osmSpell.done());
        assertFalse(ddmSpell.done());
        assertFalse(litePsmSpell.done());
    }

    function testUnauthorizedExecutionRevertsWithoutChangingEndState() public {
        vm.expectRevert();
        lineSpell.schedule();
        vm.expectRevert();
        clipSpell.schedule();
        vm.expectRevert();
        osmSpell.schedule();
        vm.expectRevert();
        ddmSpell.schedule();
        vm.expectRevert();
        litePsmSpell.schedule();

        assertFalse(lineSpell.done());
        assertFalse(clipSpell.done());
        assertFalse(osmSpell.done());
        assertFalse(ddmSpell.done());
        assertFalse(litePsmSpell.done());
    }

    function testDirectExecutionAndRepeatability() public {
        lineMom.rely(address(lineSpell));
        clipperMom.rely(address(clipSpell));
        osmMom.rely(address(osmSpell));
        ddmMom.rely(address(ddmSpell));
        litePsmMom.rely(address(litePsmSpell));

        lineSpell.schedule();
        clipSpell.schedule();
        osmSpell.schedule();
        ddmSpell.schedule();
        litePsmSpell.schedule();

        _assertAllDone();

        lineSpell.schedule();
        clipSpell.schedule();
        osmSpell.schedule();
        ddmSpell.schedule();
        litePsmSpell.schedule();

        _assertAllDone();
    }

    function testBatchExecutionUsesBatchAsAuthorizedCaller() public {
        address[] memory leaves = new address[](5);
        leaves[0] = address(lineSpell);
        leaves[1] = address(clipSpell);
        leaves[2] = address(osmSpell);
        leaves[3] = address(ddmSpell);
        leaves[4] = address(litePsmSpell);
        EmergencySpellBatchV2 batch = new EmergencySpellBatchV2(leaves, "Core leaves");

        lineMom.rely(address(batch));
        clipperMom.rely(address(batch));
        osmMom.rely(address(batch));
        ddmMom.rely(address(batch));
        litePsmMom.rely(address(batch));

        batch.schedule();

        _assertAllDone();
        assertTrue(batch.done());
        assertEq(lineMom.lastCaller(), address(batch));
        assertEq(clipperMom.lastCaller(), address(batch));
        assertEq(osmMom.lastCaller(), address(batch));
        assertEq(ddmMom.lastCaller(), address(batch));
        assertEq(litePsmMom.lastCaller(), address(batch));
    }

    function testLineDoneIncludesVatLineRegression() public {
        lineMom.rely(address(lineSpell));
        lineSpell.schedule();
        assertTrue(lineSpell.done());

        vat.setLine(ILK, 1);
        assertFalse(lineSpell.done());
    }

    function testOsmScheduleRejectsChangedRegistration() public {
        OsmMockV2 replacement = new OsmMockV2();
        osmMom.setOsm(ILK, address(replacement));
        osmMom.rely(address(osmSpell));

        vm.expectRevert("OsmStopSpellV2/osm-mismatch");
        osmSpell.schedule();
        assertFalse(osmSpell.done());
    }

    function testDoneRevertsForUnexpectedTargetInterfaces() public {
        ContractWithoutLeafInterfaceV2 invalid = new ContractWithoutLeafInterfaceV2();

        ClipBreakerSpellV2 invalidClip = new ClipBreakerSpellV2(address(clipperMom), address(invalid), ILK);
        OsmStopSpellV2 invalidOsm = new OsmStopSpellV2(address(osmMom), address(invalid), ILK);
        DdmDisableSpellV2 invalidDdm = new DdmDisableSpellV2(address(ddmMom), address(invalid), "DIRECT-SPARK-DAI");
        vm.expectRevert();
        new LitePsmHaltSpellV2(address(litePsmMom), address(invalid), Flow.BUY);

        vm.expectRevert();
        invalidClip.done();
        vm.expectRevert();
        invalidOsm.done();
        vm.expectRevert();
        invalidDdm.done();
    }

    function testLitePsmFlowVariants() public {
        _assertLitePsmFlow(Flow.SELL);
        _assertLitePsmFlow(Flow.BUY);
        _assertLitePsmFlow(Flow.BOTH);
    }

    function _assertLitePsmFlow(Flow flow) internal {
        LitePsmMockV2 psm = new LitePsmMockV2("LITE-PSM-USDC-A");
        LitePsmHaltSpellV2 spell = new LitePsmHaltSpellV2(address(litePsmMom), address(psm), flow);
        litePsmMom.rely(address(spell));

        assertFalse(spell.done());
        spell.schedule();
        assertTrue(spell.done());
        if (flow == Flow.SELL || flow == Flow.BOTH) assertEq(psm.tin(), psm.HALTED());
        if (flow == Flow.BUY || flow == Flow.BOTH) assertEq(psm.tout(), psm.HALTED());
    }

    function _assertAllDone() internal view {
        assertTrue(lineSpell.done());
        assertTrue(clipSpell.done());
        assertTrue(osmSpell.done());
        assertTrue(ddmSpell.done());
        assertTrue(litePsmSpell.done());
    }
}
