// SPDX-FileCopyrightText: © 2026 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {stdStorage, StdStorage} from "forge-std/Test.sol";
import {DssInstance, DssTest, MCD} from "dss-test/DssTest.sol";

import {GlobalClipBreakerSpellV2} from "../../src/clip-breaker/GlobalClipBreakerSpellV2.sol";
import {GlobalLineWipeSpellV2} from "../../src/line-wipe/GlobalLineWipeSpellV2.sol";
import {GlobalOsmStopSpellV2} from "../../src/osm-stop/GlobalOsmStopSpellV2.sol";

interface IlkRegistryLike {
    function xlip(bytes32 ilk) external view returns (address);
}

interface ClipLike {
    function stopped() external view returns (uint256);
}

contract GlobalSpellsV2IntegrationTest is DssTest {
    using stdStorage for StdStorage;

    address internal constant CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;

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

    function testGlobalLineWipeV2OnMainnet() public {
        GlobalLineWipeSpellV2 spell = new GlobalLineWipeSpellV2(ilkRegistry, dss.chainlog.getAddress("LINE_MOM"));
        _elect(address(spell));

        assertFalse(spell.done());
        spell.schedule();
        assertTrue(spell.done());
    }

    function testGlobalClipBreakerV2AtomicFailureAndRangeIsolationOnMainnet() public {
        GlobalClipBreakerSpellV2 spell =
            new GlobalClipBreakerSpellV2(ilkRegistry, dss.chainlog.getAddress("CLIPPER_MOM"));
        _elect(address(spell));
        address ethA = IlkRegistryLike(ilkRegistry).xlip("ETH-A");
        address ethB = IlkRegistryLike(ilkRegistry).xlip("ETH-B");
        address ethC = IlkRegistryLike(ilkRegistry).xlip("ETH-C");

        assertFalse(spell.done());
        assertEq(ClipLike(ethA).stopped(), 0);
        vm.expectRevert("Clipper/not-authorized");
        spell.schedule();
        assertEq(ClipLike(ethA).stopped(), 0);

        spell.scheduleRange(0, 2);
        assertEq(ClipLike(ethA).stopped(), 3);
        assertEq(ClipLike(ethB).stopped(), 3);
        assertEq(ClipLike(ethC).stopped(), 3);
        assertFalse(spell.done());
    }

    function testGlobalOsmStopV2OnMainnet() public {
        GlobalOsmStopSpellV2 spell = new GlobalOsmStopSpellV2(ilkRegistry, dss.chainlog.getAddress("OSM_MOM"));
        _elect(address(spell));

        assertFalse(spell.done());
        spell.schedule();
        assertTrue(spell.done());
    }

    function _elect(address spell) internal {
        stdstore.target(chief).sig("hat()").checked_write(spell);
    }
}
