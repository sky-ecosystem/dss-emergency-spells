// SPDX-FileCopyrightText: © 2026 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {Test} from "forge-std/Test.sol";

import {EmergencySpellBatchV2} from "../EmergencySpellBatchV2.sol";
import {StUsdsRateSetterDissBudSpellV2} from "./StUsdsRateSetterDissBudSpellV2.sol";

contract DissBudRateSetterMockV2 {
    address public immutable stusds;
    mapping(address => uint256) public buds;

    constructor(address stUsds_) {
        stusds = stUsds_;
    }

    function setBud(address bud, uint256 value) external {
        buds[bud] = value;
    }

    function diss(address bud) external {
        buds[bud] = 0;
    }
}

contract DissBudMomMockV2 {
    address public immutable stusds;
    mapping(address => bool) public authorized;
    address public lastCaller;

    constructor(address stUsds_) {
        stusds = stUsds_;
    }

    function rely(address caller) external {
        authorized[caller] = true;
    }

    function dissRateSetterBud(address rateSetter, address bud) external {
        require(authorized[msg.sender], "DissBudMomMockV2/not-authorized");
        lastCaller = msg.sender;
        DissBudRateSetterMockV2(rateSetter).diss(bud);
    }
}

contract InvalidDissBudRateSetterV2 {}

contract StUsdsRateSetterDissBudSpellV2Test is Test {
    address internal constant CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;
    bytes32 internal constant MCD_PAUSE = "MCD_PAUSE";

    address internal stUsds;
    address internal bud;
    DissBudRateSetterMockV2 internal rateSetter;
    DissBudMomMockV2 internal stUsdsMom;
    StUsdsRateSetterDissBudSpellV2 internal spell;

    function setUp() public {
        vm.mockCall(CHAINLOG, abi.encodeWithSignature("getAddress(bytes32)", MCD_PAUSE), abi.encode(makeAddr("pause")));
        stUsds = makeAddr("stUsds");
        bud = makeAddr("bud");
        rateSetter = new DissBudRateSetterMockV2(stUsds);
        stUsdsMom = new DissBudMomMockV2(stUsds);
        rateSetter.setBud(bud, 1);
        spell = new StUsdsRateSetterDissBudSpellV2(address(stUsdsMom), address(rateSetter), bud);
    }

    function testMetadataAndInitialState() public view {
        assertEq(spell.description(), "Emergency Spell | stUSDS | Diss Rate Setter Bud");
        assertEq(spell.stUsdsMom(), address(stUsdsMom));
        assertEq(spell.rateSetter(), address(rateSetter));
        assertEq(spell.stUsds(), stUsds);
        assertEq(spell.bud(), bud);
        assertFalse(spell.done());
    }

    function testUnauthorizedExecutionDoesNotChangeState() public {
        vm.expectRevert("DissBudMomMockV2/not-authorized");
        spell.schedule();
        assertFalse(spell.done());
        assertEq(rateSetter.buds(bud), 1);
    }

    function testDirectExecutionIsRepeatable() public {
        stUsdsMom.rely(address(spell));
        spell.schedule();
        assertTrue(spell.done());
        spell.schedule();
        assertTrue(spell.done());
        assertEq(stUsdsMom.lastCaller(), address(spell));
    }

    function testBatchExecutionUsesBatchAsCaller() public {
        address[] memory leaves = new address[](1);
        leaves[0] = address(spell);
        EmergencySpellBatchV2 batch = new EmergencySpellBatchV2(leaves, "Diss bud");
        stUsdsMom.rely(address(batch));

        batch.schedule();

        assertTrue(spell.done());
        assertEq(stUsdsMom.lastCaller(), address(batch));
    }

    function testRejectsMismatchedObjectGraph() public {
        DissBudRateSetterMockV2 other = new DissBudRateSetterMockV2(makeAddr("other-stUsds"));
        vm.expectRevert("StUsdsRateSetterDissBudSpellV2/stusds-mismatch");
        new StUsdsRateSetterDissBudSpellV2(address(stUsdsMom), address(other), bud);
    }

    function testMalformedRateSetterRevertsDuringConstruction() public {
        InvalidDissBudRateSetterV2 invalid = new InvalidDissBudRateSetterV2();
        vm.expectRevert();
        new StUsdsRateSetterDissBudSpellV2(address(stUsdsMom), address(invalid), bud);
    }
}
