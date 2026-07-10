// SPDX-FileCopyrightText: © 2026 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {Test} from "forge-std/Test.sol";

import {EmergencySpellBatchV2} from "../../src/EmergencySpellBatchV2.sol";
import {EmergencySpellV2} from "../../src/EmergencySpellV2.sol";
import {SPBEAMHaltSpellV2} from "../../src/spbeam-halt/SPBEAMHaltSpellV2.sol";
import {SplitterStopSpellV2} from "../../src/splitter-stop/SplitterStopSpellV2.sol";
import {StUsdsRateSetterDissBudSpellV2} from "../../src/stusds/StUsdsRateSetterDissBudSpellV2.sol";
import {StUsdsRateSetterHaltSpellV2} from "../../src/stusds/StUsdsRateSetterHaltSpellV2.sol";
import {StUsdsParamV2, StUsdsWipeParamSpellV2} from "../../src/stusds/StUsdsWipeParamSpellV2.sol";

contract SPBEAMMockV2 {
    uint256 public bad;

    function halt() external {
        bad = 1;
    }
}

contract SPBEAMMomMockV2 {
    mapping(address => bool) public authorized;
    address public lastCaller;

    function rely(address caller) external {
        authorized[caller] = true;
    }

    function halt(address spbeam) external {
        require(authorized[msg.sender], "SPBEAMMom/not-authorized");
        lastCaller = msg.sender;
        SPBEAMMockV2(spbeam).halt();
    }
}

contract SplitterMockV2 {
    uint256 public hop = 1 days;

    function stop() external {
        hop = type(uint256).max;
    }
}

contract SplitterMomMockV2 {
    SplitterMockV2 internal immutable splitter;
    mapping(address => bool) public authorized;
    address public lastCaller;

    constructor(address splitter_) {
        splitter = SplitterMockV2(splitter_);
    }

    function rely(address caller) external {
        authorized[caller] = true;
    }

    function stop() external {
        require(authorized[msg.sender], "SplitterMom/not-authorized");
        lastCaller = msg.sender;
        splitter.stop();
    }
}

contract StUsdsStateMockV2 {
    bytes32 public immutable ilk;
    uint256 public cap = 100;
    uint256 public line = 200;

    constructor(bytes32 ilk_) {
        ilk = ilk_;
    }

    function zeroCap() external {
        cap = 0;
    }

    function zeroLine() external {
        line = 0;
    }
}

contract StUsdsRateSetterMockV2 {
    mapping(address => uint256) public buds;
    uint8 public bad;
    uint256 public maxCap = 300;
    uint256 public maxLine = 400;

    function setBud(address bud, uint256 value) external {
        buds[bud] = value;
    }

    function diss(address bud) external {
        buds[bud] = 0;
    }

    function halt() external {
        bad = 1;
    }

    function zeroCap() external {
        maxCap = 0;
    }

    function zeroLine() external {
        maxLine = 0;
    }
}

contract VatStUsdsMockV2 {
    mapping(bytes32 => uint256) public line;

    function setLine(bytes32 ilk, uint256 line_) external {
        line[ilk] = line_;
    }

    function ilks(bytes32 ilk)
        external
        view
        returns (uint256 Art, uint256 rate, uint256 spot, uint256 line_, uint256 dust)
    {
        return (0, 0, 0, line[ilk], 0);
    }
}

contract StUsdsMomMockV2 {
    StUsdsStateMockV2 internal immutable stUsds;
    VatStUsdsMockV2 internal immutable vat;
    mapping(address => bool) public authorized;
    address public lastCaller;

    constructor(address stUsds_, address vat_) {
        stUsds = StUsdsStateMockV2(stUsds_);
        vat = VatStUsdsMockV2(vat_);
    }

    function rely(address caller) external {
        authorized[caller] = true;
    }

    function dissRateSetterBud(address rateSetter, address bud) external {
        _authorized();
        StUsdsRateSetterMockV2(rateSetter).diss(bud);
    }

    function haltRateSetter(address rateSetter) external {
        _authorized();
        StUsdsRateSetterMockV2(rateSetter).halt();
    }

    function zeroCap(address rateSetter) external {
        _authorized();
        StUsdsRateSetterMockV2(rateSetter).zeroCap();
        stUsds.zeroCap();
    }

    function zeroLine(address rateSetter) external {
        _authorized();
        StUsdsRateSetterMockV2(rateSetter).zeroLine();
        stUsds.zeroLine();
        vat.setLine(stUsds.ilk(), 0);
    }

    function _authorized() internal {
        require(authorized[msg.sender], "StUsdsMom/not-authorized");
        lastCaller = msg.sender;
    }
}

contract InvalidStandaloneTargetV2 {}

contract StandaloneLeavesV2Test is Test {
    address internal constant CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;
    bytes32 internal constant MCD_PAUSE = "MCD_PAUSE";
    bytes32 internal constant MCD_VAT = "MCD_VAT";
    bytes32 internal constant STUSDS_ILK = "STUSDS";

    InvalidStandaloneTargetV2 internal pause;
    SPBEAMMockV2 internal spbeam;
    SPBEAMMomMockV2 internal spbeamMom;
    SplitterMockV2 internal splitter;
    SplitterMomMockV2 internal splitterMom;
    StUsdsStateMockV2 internal stUsds;
    StUsdsRateSetterMockV2 internal rateSetter;
    VatStUsdsMockV2 internal vat;
    StUsdsMomMockV2 internal stUsdsMom;
    address internal bud;

    SPBEAMHaltSpellV2 internal spbeamSpell;
    SplitterStopSpellV2 internal splitterSpell;
    StUsdsRateSetterDissBudSpellV2 internal dissSpell;
    StUsdsRateSetterHaltSpellV2 internal haltSpell;
    StUsdsWipeParamSpellV2 internal wipeSpell;

    function setUp() public {
        pause = new InvalidStandaloneTargetV2();
        vat = new VatStUsdsMockV2();
        vm.mockCall(CHAINLOG, abi.encodeWithSignature("getAddress(bytes32)", MCD_PAUSE), abi.encode(address(pause)));
        vm.mockCall(CHAINLOG, abi.encodeWithSignature("getAddress(bytes32)", MCD_VAT), abi.encode(address(vat)));

        spbeam = new SPBEAMMockV2();
        spbeamMom = new SPBEAMMomMockV2();
        splitter = new SplitterMockV2();
        splitterMom = new SplitterMomMockV2(address(splitter));
        stUsds = new StUsdsStateMockV2(STUSDS_ILK);
        rateSetter = new StUsdsRateSetterMockV2();
        stUsdsMom = new StUsdsMomMockV2(address(stUsds), address(vat));
        bud = makeAddr("bud");
        rateSetter.setBud(bud, 1);
        vat.setLine(STUSDS_ILK, 500);

        spbeamSpell = new SPBEAMHaltSpellV2(address(spbeamMom), address(spbeam));
        splitterSpell = new SplitterStopSpellV2(address(splitterMom), address(splitter));
        dissSpell = new StUsdsRateSetterDissBudSpellV2(address(stUsdsMom), address(rateSetter), bud);
        haltSpell = new StUsdsRateSetterHaltSpellV2(address(stUsdsMom), address(rateSetter));
        wipeSpell =
            new StUsdsWipeParamSpellV2(address(stUsdsMom), address(rateSetter), address(stUsds), StUsdsParamV2.BOTH);
    }

    function testDescriptionsAndInitialEndStates() public view {
        assertEq(spbeamSpell.description(), "Emergency Spell | Halt SPBEAM");
        assertEq(splitterSpell.description(), "Emergency Spell | Stop Splitter");
        assertEq(dissSpell.description(), "Emergency Spell | stUSDS | Diss Rate Setter Bud");
        assertEq(haltSpell.description(), "Emergency Spell | stUSDS | Halt Rate Setter");
        assertEq(wipeSpell.description(), "Emergency Spell | stUSDS | wipe param: BOTH");
        _assertAllNotDone();
    }

    function testDirectExecutionAndRepeatability() public {
        _authorize(
            address(spbeamSpell), address(splitterSpell), address(dissSpell), address(haltSpell), address(wipeSpell)
        );
        _scheduleAll();
        _assertAllDone();
        _scheduleAll();
        _assertAllDone();
    }

    function testBatchExecutionUsesBatchAsAuthorizedCaller() public {
        address[] memory leaves = new address[](5);
        leaves[0] = address(spbeamSpell);
        leaves[1] = address(splitterSpell);
        leaves[2] = address(dissSpell);
        leaves[3] = address(haltSpell);
        leaves[4] = address(wipeSpell);
        EmergencySpellBatchV2 batch = new EmergencySpellBatchV2(leaves, "Standalone leaves");
        _authorize(address(batch), address(batch), address(batch), address(batch), address(batch));

        batch.schedule();

        _assertAllDone();
        assertTrue(batch.done());
        assertEq(spbeamMom.lastCaller(), address(batch));
        assertEq(splitterMom.lastCaller(), address(batch));
        assertEq(stUsdsMom.lastCaller(), address(batch));
    }

    function testUnauthorizedExecutionRevertsWithoutChangingEndState() public {
        vm.expectRevert();
        spbeamSpell.schedule();
        vm.expectRevert();
        splitterSpell.schedule();
        vm.expectRevert();
        dissSpell.schedule();
        vm.expectRevert();
        haltSpell.schedule();
        vm.expectRevert();
        wipeSpell.schedule();
        _assertAllNotDone();
    }

    function testWipeParamVariants() public {
        _assertWipeParam(StUsdsParamV2.CAP);
        _resetWipeState();
        _assertWipeParam(StUsdsParamV2.LINE);
        _resetWipeState();
        _assertWipeParam(StUsdsParamV2.BOTH);
    }

    function testWipeLineDoneIncludesVatRegression() public {
        stUsdsMom.rely(address(wipeSpell));
        wipeSpell.schedule();
        assertTrue(wipeSpell.done());

        vat.setLine(STUSDS_ILK, 1);
        assertFalse(wipeSpell.done());
    }

    function testUnexpectedInterfacesRevertInsteadOfReportingDone() public {
        InvalidStandaloneTargetV2 invalid = new InvalidStandaloneTargetV2();
        SPBEAMHaltSpellV2 invalidSpbeam = new SPBEAMHaltSpellV2(address(spbeamMom), address(invalid));
        SplitterStopSpellV2 invalidSplitter = new SplitterStopSpellV2(address(splitterMom), address(invalid));
        StUsdsRateSetterDissBudSpellV2 invalidDiss =
            new StUsdsRateSetterDissBudSpellV2(address(stUsdsMom), address(invalid), bud);
        StUsdsRateSetterHaltSpellV2 invalidHalt = new StUsdsRateSetterHaltSpellV2(address(stUsdsMom), address(invalid));

        vm.expectRevert();
        invalidSpbeam.done();
        vm.expectRevert();
        invalidSplitter.done();
        vm.expectRevert();
        invalidDiss.done();
        vm.expectRevert();
        invalidHalt.done();
        vm.expectRevert();
        new StUsdsWipeParamSpellV2(address(stUsdsMom), address(rateSetter), address(invalid), StUsdsParamV2.BOTH);
    }

    function testConstructorsRejectAddressesWithoutCode() public {
        address invalid = makeAddr("invalid");
        vm.expectRevert(abi.encodeWithSelector(EmergencySpellV2.InvalidContract.selector, invalid));
        new SPBEAMHaltSpellV2(address(spbeamMom), invalid);
        vm.expectRevert(abi.encodeWithSelector(EmergencySpellV2.InvalidContract.selector, invalid));
        new SplitterStopSpellV2(address(splitterMom), invalid);
        vm.expectRevert(abi.encodeWithSelector(EmergencySpellV2.InvalidContract.selector, invalid));
        new StUsdsRateSetterDissBudSpellV2(address(stUsdsMom), invalid, bud);
        vm.expectRevert(abi.encodeWithSelector(EmergencySpellV2.InvalidContract.selector, invalid));
        new StUsdsRateSetterHaltSpellV2(address(stUsdsMom), invalid);
        vm.expectRevert(abi.encodeWithSelector(EmergencySpellV2.InvalidContract.selector, invalid));
        new StUsdsWipeParamSpellV2(address(stUsdsMom), address(rateSetter), invalid, StUsdsParamV2.BOTH);
    }

    function _authorize(
        address spbeamCaller,
        address splitterCaller,
        address dissCaller,
        address haltCaller,
        address wipeCaller
    ) internal {
        spbeamMom.rely(spbeamCaller);
        splitterMom.rely(splitterCaller);
        stUsdsMom.rely(dissCaller);
        stUsdsMom.rely(haltCaller);
        stUsdsMom.rely(wipeCaller);
    }

    function _scheduleAll() internal {
        spbeamSpell.schedule();
        splitterSpell.schedule();
        dissSpell.schedule();
        haltSpell.schedule();
        wipeSpell.schedule();
    }

    function _assertAllDone() internal view {
        assertTrue(spbeamSpell.done());
        assertTrue(splitterSpell.done());
        assertTrue(dissSpell.done());
        assertTrue(haltSpell.done());
        assertTrue(wipeSpell.done());
    }

    function _assertAllNotDone() internal view {
        assertFalse(spbeamSpell.done());
        assertFalse(splitterSpell.done());
        assertFalse(dissSpell.done());
        assertFalse(haltSpell.done());
        assertFalse(wipeSpell.done());
    }

    function _assertWipeParam(StUsdsParamV2 param) internal {
        StUsdsWipeParamSpellV2 spell =
            new StUsdsWipeParamSpellV2(address(stUsdsMom), address(rateSetter), address(stUsds), param);
        stUsdsMom.rely(address(spell));
        assertFalse(spell.done());
        spell.schedule();
        assertTrue(spell.done());
    }

    function _resetWipeState() internal {
        stUsds = new StUsdsStateMockV2(STUSDS_ILK);
        rateSetter = new StUsdsRateSetterMockV2();
        stUsdsMom = new StUsdsMomMockV2(address(stUsds), address(vat));
        vat.setLine(STUSDS_ILK, 500);
    }
}
