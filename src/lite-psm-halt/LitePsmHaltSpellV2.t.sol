// SPDX-FileCopyrightText: © 2026 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {Test} from "forge-std/Test.sol";

import {EmergencySpellBatchV2} from "../EmergencySpellBatchV2.sol";
import {Flow, LitePsmHaltSpellV2} from "./LitePsmHaltSpellV2.sol";

contract LitePsmLeafMockV2 {
    bytes32 public immutable ilk;
    uint256 public constant HALTED = type(uint256).max;
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

contract LitePsmMomLeafMockV2 {
    mapping(address => bool) public authorized;
    address public lastCaller;

    function rely(address caller) external {
        authorized[caller] = true;
    }

    function halt(address psm, Flow flow) external {
        require(authorized[msg.sender], "LitePsmMomLeafMockV2/not-authorized");
        lastCaller = msg.sender;
        LitePsmLeafMockV2(psm).halt(flow);
    }
}

contract InvalidLitePsmV2 {}

contract LitePsmHaltSpellV2Test is Test {
    address internal constant CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;
    bytes32 internal constant MCD_PAUSE = "MCD_PAUSE";
    bytes32 internal constant ILK = "LITE-PSM-USDC-A";

    LitePsmMomLeafMockV2 internal litePsmMom;

    function setUp() public {
        vm.mockCall(CHAINLOG, abi.encodeWithSignature("getAddress(bytes32)", MCD_PAUSE), abi.encode(makeAddr("pause")));
        litePsmMom = new LitePsmMomLeafMockV2();
    }

    function testSellBuyAndBothVariantsAreRepeatable() public {
        _assertFlow(Flow.SELL, "SELL");
        _assertFlow(Flow.BUY, "BUY");
        _assertFlow(Flow.BOTH, "BOTH");
    }

    function testUnauthorizedExecutionDoesNotChangeState() public {
        LitePsmLeafMockV2 psm = new LitePsmLeafMockV2(ILK);
        LitePsmHaltSpellV2 spell = new LitePsmHaltSpellV2(address(litePsmMom), address(psm), Flow.BOTH);
        vm.expectRevert("LitePsmMomLeafMockV2/not-authorized");
        spell.schedule();
        assertFalse(spell.done());
        assertEq(psm.tin(), 1);
        assertEq(psm.tout(), 2);
    }

    function testBatchExecutionUsesBatchAsCaller() public {
        LitePsmLeafMockV2 psm = new LitePsmLeafMockV2(ILK);
        LitePsmHaltSpellV2 spell = new LitePsmHaltSpellV2(address(litePsmMom), address(psm), Flow.BOTH);
        address[] memory leaves = new address[](1);
        leaves[0] = address(spell);
        EmergencySpellBatchV2 batch = new EmergencySpellBatchV2(leaves, "Lite PSM halt");
        litePsmMom.rely(address(batch));

        batch.schedule();

        assertTrue(spell.done());
        assertEq(litePsmMom.lastCaller(), address(batch));
    }

    function testMalformedPsmRevertsDuringConstruction() public {
        InvalidLitePsmV2 invalid = new InvalidLitePsmV2();
        vm.expectRevert();
        new LitePsmHaltSpellV2(address(litePsmMom), address(invalid), Flow.BUY);
    }

    function _assertFlow(Flow flow, string memory label) internal {
        LitePsmLeafMockV2 psm = new LitePsmLeafMockV2(ILK);
        LitePsmHaltSpellV2 spell = new LitePsmHaltSpellV2(address(litePsmMom), address(psm), flow);
        litePsmMom.rely(address(spell));

        assertEq(spell.description(), string(abi.encodePacked("Emergency Spell | ", ILK, " | halt: ", label)));
        assertEq(spell.litePsmMom(), address(litePsmMom));
        assertEq(spell.psm(), address(psm));
        assertEq(uint256(spell.flow()), uint256(flow));
        assertEq(spell.ilk(), ILK);
        assertFalse(spell.done());

        spell.schedule();
        assertTrue(spell.done());
        if (flow == Flow.SELL) {
            assertEq(psm.tin(), psm.HALTED());
            assertEq(psm.tout(), 2);
        } else if (flow == Flow.BUY) {
            assertEq(psm.tin(), 1);
            assertEq(psm.tout(), psm.HALTED());
        } else {
            assertEq(psm.tin(), psm.HALTED());
            assertEq(psm.tout(), psm.HALTED());
        }

        spell.schedule();
        assertTrue(spell.done());
    }
}
