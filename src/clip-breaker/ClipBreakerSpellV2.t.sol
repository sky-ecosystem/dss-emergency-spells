// SPDX-FileCopyrightText: © 2026 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {Test} from "forge-std/Test.sol";

import {EmergencySpellBatchV2} from "../EmergencySpellBatchV2.sol";
import {ClipBreakerSpellV2} from "./ClipBreakerSpellV2.sol";

contract ClipBreakerTargetMockV2 {
    uint256 public stopped;

    function setStopped(uint256 stopped_) external {
        stopped = stopped_;
    }
}

contract ClipperMomLeafMockV2 {
    mapping(address => bool) public authorized;
    address public lastCaller;

    function rely(address caller) external {
        authorized[caller] = true;
    }

    function setBreaker(address clip, uint256 level, uint256) external {
        require(authorized[msg.sender], "ClipperMomLeafMockV2/not-authorized");
        lastCaller = msg.sender;
        ClipBreakerTargetMockV2(clip).setStopped(level);
    }
}

contract InvalidClipTargetV2 {}

contract ClipBreakerSpellV2Test is Test {
    address internal constant CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;
    bytes32 internal constant MCD_PAUSE = "MCD_PAUSE";
    bytes32 internal constant ILK = "ETH-A";

    ClipBreakerTargetMockV2 internal clip;
    ClipperMomLeafMockV2 internal clipperMom;
    ClipBreakerSpellV2 internal spell;

    function setUp() public {
        vm.mockCall(CHAINLOG, abi.encodeWithSignature("getAddress(bytes32)", MCD_PAUSE), abi.encode(makeAddr("pause")));
        clip = new ClipBreakerTargetMockV2();
        clipperMom = new ClipperMomLeafMockV2();
        spell = new ClipBreakerSpellV2(address(clipperMom), address(clip), ILK);
    }

    function testMetadataAndInitialState() public view {
        assertEq(spell.description(), string(abi.encodePacked("Emergency Spell | Set Clip Breaker: ", ILK)));
        assertEq(spell.clipperMom(), address(clipperMom));
        assertEq(spell.clip(), address(clip));
        assertEq(spell.ilk(), ILK);
        assertFalse(spell.done());
    }

    function testUnauthorizedExecutionDoesNotChangeState() public {
        vm.expectRevert("ClipperMomLeafMockV2/not-authorized");
        spell.schedule();
        assertFalse(spell.done());
        assertEq(clip.stopped(), 0);
    }

    function testDirectExecutionIsRepeatable() public {
        clipperMom.rely(address(spell));
        spell.schedule();
        assertTrue(spell.done());
        spell.schedule();
        assertTrue(spell.done());
        assertEq(clipperMom.lastCaller(), address(spell));
    }

    function testBatchExecutionUsesBatchAsCaller() public {
        address[] memory leaves = new address[](1);
        leaves[0] = address(spell);
        EmergencySpellBatchV2 batch = new EmergencySpellBatchV2(leaves, "Clip breaker");
        clipperMom.rely(address(batch));

        batch.schedule();

        assertTrue(spell.done());
        assertEq(clipperMom.lastCaller(), address(batch));
    }

    function testMalformedClipRevertsInsteadOfReportingDone() public {
        ClipBreakerSpellV2 broken = new ClipBreakerSpellV2(address(clipperMom), address(new InvalidClipTargetV2()), ILK);
        vm.expectRevert();
        broken.done();
    }
}
