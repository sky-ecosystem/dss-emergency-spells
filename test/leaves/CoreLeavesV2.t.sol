// SPDX-FileCopyrightText: © 2026 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {Test} from "forge-std/Test.sol";

import {SingleClipBreakerSpellV2} from "../../src/clip-breaker/SingleClipBreakerSpellV2.sol";
import {SingleDdmDisableSpellV2} from "../../src/ddm-disable/SingleDdmDisableSpellV2.sol";
import {EmergencySpellBatchV2} from "../../src/EmergencySpellBatchV2.sol";
import {EmergencySpellV2} from "../../src/EmergencySpellV2.sol";
import {SingleLineWipeSpellV2} from "../../src/line-wipe/SingleLineWipeSpellV2.sol";
import {FlowV2, SingleLitePsmHaltSpellV2} from "../../src/lite-psm-halt/SingleLitePsmHaltSpellV2.sol";
import {SingleOsmStopSpellV2} from "../../src/osm-stop/SingleOsmStopSpellV2.sol";

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

    function halt(FlowV2 flow) external {
        if (flow == FlowV2.SELL || flow == FlowV2.BOTH) tin = HALTED;
        if (flow == FlowV2.BUY || flow == FlowV2.BOTH) tout = HALTED;
    }
}

contract LitePsmMomMockV2 {
    mapping(address => bool) public authorized;
    address public lastCaller;

    function rely(address caller) external {
        authorized[caller] = true;
    }

    function halt(address psm, FlowV2 flow) external {
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

    SingleLineWipeSpellV2 internal lineSpell;
    SingleClipBreakerSpellV2 internal clipSpell;
    SingleOsmStopSpellV2 internal osmSpell;
    SingleDdmDisableSpellV2 internal ddmSpell;
    SingleLitePsmHaltSpellV2 internal litePsmSpell;

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

        lineSpell = new SingleLineWipeSpellV2(address(lineMom), ILK);
        clipSpell = new SingleClipBreakerSpellV2(address(clipperMom), address(clip), ILK);
        osmSpell = new SingleOsmStopSpellV2(address(osmMom), address(osm), ILK);
        ddmSpell = new SingleDdmDisableSpellV2(address(ddmMom), address(ddmPlan), "DIRECT-SPARK-DAI");
        litePsmSpell = new SingleLitePsmHaltSpellV2(address(litePsmMom), address(litePsm), FlowV2.BOTH);
    }

    function testDescriptionsIdentifyExplicitSubjects() public view {
        assertEq(lineSpell.description(), "Emergency Spell | Line Wipe: ETH-A");
        assertEq(clipSpell.description(), "Emergency Spell | Set Clip Breaker: ETH-A");
        assertEq(osmSpell.description(), "Emergency Spell | OSM Stop: ETH-A");
        assertEq(ddmSpell.description(), "Emergency Spell | Disable DDM Plan: DIRECT-SPARK-DAI");
        assertEq(litePsmSpell.description(), "Emergency Spell | LITE-PSM-USDC-A | halt: BOTH");
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

        vm.expectRevert(
            abi.encodeWithSelector(SingleOsmStopSpellV2.OsmMismatch.selector, address(osm), address(replacement))
        );
        osmSpell.schedule();
        assertFalse(osmSpell.done());
    }

    function testDoneRevertsForUnexpectedTargetInterfaces() public {
        ContractWithoutLeafInterfaceV2 invalid = new ContractWithoutLeafInterfaceV2();

        SingleClipBreakerSpellV2 invalidClip = new SingleClipBreakerSpellV2(address(clipperMom), address(invalid), ILK);
        SingleOsmStopSpellV2 invalidOsm = new SingleOsmStopSpellV2(address(osmMom), address(invalid), ILK);
        SingleDdmDisableSpellV2 invalidDdm =
            new SingleDdmDisableSpellV2(address(ddmMom), address(invalid), "DIRECT-SPARK-DAI");
        vm.expectRevert();
        new SingleLitePsmHaltSpellV2(address(litePsmMom), address(invalid), FlowV2.BUY);

        vm.expectRevert();
        invalidClip.done();
        vm.expectRevert();
        invalidOsm.done();
        vm.expectRevert();
        invalidDdm.done();
    }

    function testLitePsmFlowVariants() public {
        _assertLitePsmFlow(FlowV2.SELL);
        _assertLitePsmFlow(FlowV2.BUY);
        _assertLitePsmFlow(FlowV2.BOTH);
    }

    function testConstructorsRejectAddressesWithoutCode() public {
        address invalid = makeAddr("invalid");

        vm.expectRevert(abi.encodeWithSelector(EmergencySpellV2.InvalidContract.selector, invalid));
        new SingleLineWipeSpellV2(invalid, ILK);
        vm.expectRevert(abi.encodeWithSelector(EmergencySpellV2.InvalidContract.selector, invalid));
        new SingleClipBreakerSpellV2(address(clipperMom), invalid, ILK);
        vm.expectRevert(abi.encodeWithSelector(EmergencySpellV2.InvalidContract.selector, invalid));
        new SingleOsmStopSpellV2(address(osmMom), invalid, ILK);
        vm.expectRevert(abi.encodeWithSelector(EmergencySpellV2.InvalidContract.selector, invalid));
        new SingleDdmDisableSpellV2(address(ddmMom), invalid, "DIRECT-SPARK-DAI");
        vm.expectRevert(abi.encodeWithSelector(EmergencySpellV2.InvalidContract.selector, invalid));
        new SingleLitePsmHaltSpellV2(address(litePsmMom), invalid, FlowV2.BOTH);
    }

    function testLineConstructorRejectsInvalidDerivedAutoLine() public {
        address invalid = makeAddr("invalid-auto-line");
        BrokenLineMomMockV2 brokenLineMom = new BrokenLineMomMockV2(invalid);

        vm.expectRevert(abi.encodeWithSelector(EmergencySpellV2.InvalidContract.selector, invalid));
        new SingleLineWipeSpellV2(address(brokenLineMom), ILK);
    }

    function testLineConstructorRejectsInvalidAmbientVat() public {
        address invalid = makeAddr("invalid-vat");
        vm.mockCall(CHAINLOG, abi.encodeWithSignature("getAddress(bytes32)", MCD_VAT), abi.encode(invalid));

        vm.expectRevert(abi.encodeWithSelector(EmergencySpellV2.InvalidContract.selector, invalid));
        new SingleLineWipeSpellV2(address(lineMom), ILK);
    }

    function _assertLitePsmFlow(FlowV2 flow) internal {
        LitePsmMockV2 psm = new LitePsmMockV2("LITE-PSM-USDC-A");
        SingleLitePsmHaltSpellV2 spell = new SingleLitePsmHaltSpellV2(address(litePsmMom), address(psm), flow);
        litePsmMom.rely(address(spell));

        assertFalse(spell.done());
        spell.schedule();
        assertTrue(spell.done());
        if (flow == FlowV2.SELL || flow == FlowV2.BOTH) assertEq(psm.tin(), psm.HALTED());
        if (flow == FlowV2.BUY || flow == FlowV2.BOTH) assertEq(psm.tout(), psm.HALTED());
    }

    function _assertAllDone() internal view {
        assertTrue(lineSpell.done());
        assertTrue(clipSpell.done());
        assertTrue(osmSpell.done());
        assertTrue(ddmSpell.done());
        assertTrue(litePsmSpell.done());
    }
}
