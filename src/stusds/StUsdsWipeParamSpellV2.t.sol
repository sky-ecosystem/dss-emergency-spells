// SPDX-FileCopyrightText: © 2026 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {Test} from "forge-std/Test.sol";

import {EmergencySpellBatchV2} from "../EmergencySpellBatchV2.sol";
import {Param, StUsdsWipeParamSpellV2} from "./StUsdsWipeParamSpellV2.sol";

contract WipeParamStUsdsMockV2 {
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

contract WipeParamRateSetterMockV2 {
    address public immutable stusds;
    uint256 public maxCap = 300;
    uint256 public maxLine = 400;

    constructor(address stUsds_) {
        stusds = stUsds_;
    }

    function zeroCap() external {
        maxCap = 0;
    }

    function zeroLine() external {
        maxLine = 0;
    }
}

contract WipeParamVatMockV2 {
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

contract WipeParamMomMockV2 {
    address public immutable stusds;
    WipeParamVatMockV2 internal immutable vat;
    mapping(address => bool) public authorized;
    address public lastCaller;

    constructor(address stUsds_, address vat_) {
        stusds = stUsds_;
        vat = WipeParamVatMockV2(vat_);
    }

    function rely(address caller) external {
        authorized[caller] = true;
    }

    function zeroCap(address rateSetter) external {
        _authorized();
        WipeParamRateSetterMockV2(rateSetter).zeroCap();
        WipeParamStUsdsMockV2(stusds).zeroCap();
    }

    function zeroLine(address rateSetter) external {
        _authorized();
        WipeParamRateSetterMockV2(rateSetter).zeroLine();
        WipeParamStUsdsMockV2(stusds).zeroLine();
        vat.setLine(WipeParamStUsdsMockV2(stusds).ilk(), 0);
    }

    function _authorized() internal {
        require(authorized[msg.sender], "WipeParamMomMockV2/not-authorized");
        lastCaller = msg.sender;
    }
}

contract InvalidWipeParamTargetV2 {}

contract StUsdsWipeParamSpellV2Test is Test {
    address internal constant CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;
    bytes32 internal constant MCD_PAUSE = "MCD_PAUSE";
    bytes32 internal constant MCD_VAT = "MCD_VAT";
    bytes32 internal constant ILK = "STUSDS";

    WipeParamVatMockV2 internal vat;
    WipeParamStUsdsMockV2 internal stUsds;
    WipeParamRateSetterMockV2 internal rateSetter;
    WipeParamMomMockV2 internal stUsdsMom;

    function setUp() public {
        vat = new WipeParamVatMockV2();
        vm.mockCall(CHAINLOG, abi.encodeWithSignature("getAddress(bytes32)", MCD_PAUSE), abi.encode(makeAddr("pause")));
        vm.mockCall(CHAINLOG, abi.encodeWithSignature("getAddress(bytes32)", MCD_VAT), abi.encode(address(vat)));
        _resetState();
    }

    function testCapLineAndBothVariantsAreRepeatableWithExactResidualState() public {
        _assertParam(Param.CAP, "CAP");
        _resetState();
        _assertParam(Param.LINE, "LINE");
        _resetState();
        _assertParam(Param.BOTH, "BOTH");
    }

    function testUnauthorizedExecutionDoesNotChangeState() public {
        StUsdsWipeParamSpellV2 spell = _newSpell(Param.BOTH);
        vm.expectRevert("WipeParamMomMockV2/not-authorized");
        spell.schedule();
        assertFalse(spell.done());
        _assertInitialState();
    }

    function testBatchExecutionUsesBatchAsCaller() public {
        StUsdsWipeParamSpellV2 spell = _newSpell(Param.BOTH);
        address[] memory leaves = new address[](1);
        leaves[0] = address(spell);
        EmergencySpellBatchV2 batch = new EmergencySpellBatchV2(leaves, "Wipe stUSDS params");
        stUsdsMom.rely(address(batch));

        batch.schedule();

        assertTrue(spell.done());
        assertEq(stUsdsMom.lastCaller(), address(batch));
    }

    function testDoneIncludesVatLine() public {
        StUsdsWipeParamSpellV2 spell = _newSpell(Param.LINE);
        stUsdsMom.rely(address(spell));
        spell.schedule();
        assertTrue(spell.done());
        vat.setLine(ILK, 1);
        assertFalse(spell.done());
    }

    function testRejectsMismatchedObjectGraphs() public {
        WipeParamStUsdsMockV2 otherStUsds = new WipeParamStUsdsMockV2("OTHER");
        WipeParamRateSetterMockV2 otherRateSetter = new WipeParamRateSetterMockV2(address(otherStUsds));

        vm.expectRevert("StUsdsWipeParamSpellV2/stusds-mismatch");
        new StUsdsWipeParamSpellV2(address(stUsdsMom), address(rateSetter), address(otherStUsds), Param.BOTH);
        vm.expectRevert("StUsdsWipeParamSpellV2/stusds-mismatch");
        new StUsdsWipeParamSpellV2(address(stUsdsMom), address(otherRateSetter), address(stUsds), Param.BOTH);
    }

    function testMalformedStUsdsRevertsDuringConstruction() public {
        InvalidWipeParamTargetV2 invalid = new InvalidWipeParamTargetV2();
        vm.expectRevert();
        new StUsdsWipeParamSpellV2(address(stUsdsMom), address(rateSetter), address(invalid), Param.BOTH);
    }

    function _assertParam(Param param, string memory label) internal {
        StUsdsWipeParamSpellV2 spell = _newSpell(param);
        stUsdsMom.rely(address(spell));

        assertEq(spell.description(), string.concat("Emergency Spell | stUSDS | wipe param: ", label));
        assertEq(spell.stUsdsMom(), address(stUsdsMom));
        assertEq(spell.rateSetter(), address(rateSetter));
        assertEq(spell.stUsds(), address(stUsds));
        assertEq(spell.vat(), address(vat));
        assertEq(uint256(spell.param()), uint256(param));
        assertEq(spell.ilk(), ILK);
        assertFalse(spell.done());

        spell.schedule();
        assertTrue(spell.done());
        _assertResult(param);

        spell.schedule();
        assertTrue(spell.done());
        _assertResult(param);
    }

    function _assertResult(Param param) internal view {
        if (param == Param.CAP) {
            assertEq(stUsds.cap(), 0);
            assertEq(rateSetter.maxCap(), 0);
            assertEq(stUsds.line(), 200);
            assertEq(rateSetter.maxLine(), 400);
            assertEq(vat.line(ILK), 500);
        } else if (param == Param.LINE) {
            assertEq(stUsds.cap(), 100);
            assertEq(rateSetter.maxCap(), 300);
            assertEq(stUsds.line(), 0);
            assertEq(rateSetter.maxLine(), 0);
            assertEq(vat.line(ILK), 0);
        } else {
            assertEq(stUsds.cap(), 0);
            assertEq(rateSetter.maxCap(), 0);
            assertEq(stUsds.line(), 0);
            assertEq(rateSetter.maxLine(), 0);
            assertEq(vat.line(ILK), 0);
        }
    }

    function _assertInitialState() internal view {
        assertEq(stUsds.cap(), 100);
        assertEq(rateSetter.maxCap(), 300);
        assertEq(stUsds.line(), 200);
        assertEq(rateSetter.maxLine(), 400);
        assertEq(vat.line(ILK), 500);
    }

    function _newSpell(Param param) internal returns (StUsdsWipeParamSpellV2) {
        return new StUsdsWipeParamSpellV2(address(stUsdsMom), address(rateSetter), address(stUsds), param);
    }

    function _resetState() internal {
        stUsds = new WipeParamStUsdsMockV2(ILK);
        rateSetter = new WipeParamRateSetterMockV2(address(stUsds));
        stUsdsMom = new WipeParamMomMockV2(address(stUsds), address(vat));
        vat.setLine(ILK, 500);
    }
}
