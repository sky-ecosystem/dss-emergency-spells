// SPDX-FileCopyrightText: © 2026 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {stdStorage, StdStorage} from "forge-std/Test.sol";
import {DssInstance, DssTest, MCD} from "dss-test/DssTest.sol";

import {GlobalClipBreakerSpellV2} from "./GlobalClipBreakerSpellV2.sol";

interface IlkRegistryLike {
    function count() external view returns (uint256);
    function list() external view returns (bytes32[] memory);
    function list(uint256 start, uint256 end) external view returns (bytes32[] memory);
    function xlip(bytes32 ilk) external view returns (address);
}

interface ClipLike {
    function stopped() external view returns (uint256);
    function wards(address who) external view returns (uint256);
}

contract GlobalClipBreakerSpellV2IntegrationTest is DssTest {
    using stdStorage for StdStorage;

    address internal constant CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;
    uint256 internal constant PSM_GUSD_INDEX = 9;
    bytes32 internal constant PSM_GUSD_ILK = "PSM-GUSD-A";
    address internal constant PSM_GUSD_CLIP = 0xf93CC3a50f450ED245e003BFecc8A6Ec1732b0b2;

    DssInstance internal dss;
    address internal chief;
    address internal ilkRegistry;

    function setUp() public {
        vm.createSelectFork("mainnet");
        dss = MCD.loadFromChainlog(CHAINLOG);
        MCD.giveAdminAccess(dss);
        chief = dss.chainlog.getAddress("MCD_ADM");
        ilkRegistry = dss.chainlog.getAddress("ILK_REGISTRY");
        vm.makePersistent(chief);
    }

    function testGlobalClipBreakerV2AtomicFailureAndRangeIsolationOnMainnet() public {
        address clipperMom = dss.chainlog.getAddress("CLIPPER_MOM");
        GlobalClipBreakerSpellV2 spell = new GlobalClipBreakerSpellV2(ilkRegistry, clipperMom);
        stdstore.target(chief).sig("hat()").checked_write(address(spell));
        IlkRegistryLike registry = IlkRegistryLike(ilkRegistry);
        bytes32[] memory isolatedIlk = registry.list(PSM_GUSD_INDEX, PSM_GUSD_INDEX);
        uint256 count = registry.count();
        address ethA = registry.xlip("ETH-A");

        assertEq(isolatedIlk.length, 1);
        assertEq(isolatedIlk[0], PSM_GUSD_ILK);
        assertEq(registry.xlip(PSM_GUSD_ILK), PSM_GUSD_CLIP);
        assertGt(count, PSM_GUSD_INDEX + 1);
        assertEq(ClipLike(PSM_GUSD_CLIP).wards(clipperMom), 0);
        assertEq(ClipLike(PSM_GUSD_CLIP).stopped(), 3);

        assertFalse(spell.done());
        assertEq(ClipLike(ethA).stopped(), 0);
        vm.expectRevert("Clipper/not-authorized");
        spell.schedule();
        assertEq(ClipLike(ethA).stopped(), 0);
        vm.expectRevert("Clipper/not-authorized");
        spell.scheduleRange(PSM_GUSD_INDEX, PSM_GUSD_INDEX);

        bytes32[] memory ilks = registry.list();
        bool[] memory blocked = new bool[](count);
        uint256[] memory initialStopped = new uint256[](count);
        uint256 rangeStart;
        for (uint256 i; i < ilks.length; ++i) {
            address clip = registry.xlip(ilks[i]);
            if (clip == address(0)) continue;
            initialStopped[i] = ClipLike(clip).stopped();
            if (ClipLike(clip).wards(clipperMom) != 0) continue;

            if (rangeStart < i) spell.scheduleRange(rangeStart, i - 1);
            vm.expectRevert();
            spell.scheduleRange(i, i);
            blocked[i] = true;
            rangeStart = i + 1;
        }
        if (rangeStart < count) spell.scheduleRange(rangeStart, type(uint256).max);

        assertTrue(blocked[PSM_GUSD_INDEX]);
        bool incompleteBlockedTarget;
        for (uint256 i; i < ilks.length; ++i) {
            address clip = registry.xlip(ilks[i]);
            if (clip == address(0)) continue;
            if (blocked[i]) {
                assertEq(ClipLike(clip).stopped(), initialStopped[i]);
                if (initialStopped[i] != 3) incompleteBlockedTarget = true;
                continue;
            }
            assertEq(ClipLike(clip).stopped(), 3);
        }
        assertEq(spell.done(), !incompleteBlockedTarget);
    }
}
