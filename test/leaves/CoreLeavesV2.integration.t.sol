// SPDX-FileCopyrightText: © 2026 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {stdStorage, StdStorage} from "forge-std/Test.sol";
import {DssInstance, DssTest, MCD} from "dss-test/DssTest.sol";

import {ClipBreakerSpellV2} from "../../src/clip-breaker/ClipBreakerSpellV2.sol";
import {DdmDisableSpellV2} from "../../src/ddm-disable/DdmDisableSpellV2.sol";
import {EmergencySpellBatchV2} from "../../src/EmergencySpellBatchV2.sol";
import {DssEmergencySpellLike} from "../../src/EmergencySpellV2.sol";
import {LineWipeSpellV2} from "../../src/line-wipe/LineWipeSpellV2.sol";
import {Flow, LitePsmHaltSpellV2} from "../../src/lite-psm-halt/LitePsmHaltSpellV2.sol";
import {OsmStopSpellV2} from "../../src/osm-stop/OsmStopSpellV2.sol";

interface IlkRegistryForLeaves {
    function xlip(bytes32 ilk) external view returns (address);
}

interface OsmMomForLeaves {
    function osms(bytes32 ilk) external view returns (address);
}

interface DdmHubForLeaves {
    function plan(bytes32 ilk) external view returns (address);
}

contract CoreLeavesV2IntegrationTest is DssTest {
    using stdStorage for StdStorage;

    address internal constant CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;
    bytes32 internal constant ILK = "ETH-A";

    DssInstance internal dss;
    address internal chief;

    function setUp() public {
        vm.createSelectFork("mainnet");
        dss = MCD.loadFromChainlog(CHAINLOG);
        MCD.giveAdminAccess(dss);
        chief = dss.chainlog.getAddress("MCD_ADM");
        vm.makePersistent(chief);
    }

    function testLineWipeV2OnMainnet() public {
        DssEmergencySpellLike spell =
            DssEmergencySpellLike(address(new LineWipeSpellV2(dss.chainlog.getAddress("LINE_MOM"), ILK)));
        _elect(address(spell));

        assertFalse(spell.done());
        spell.schedule();
        assertTrue(spell.done());
    }

    function testClipBreakerV2OnMainnet() public {
        address clip = IlkRegistryForLeaves(dss.chainlog.getAddress("ILK_REGISTRY")).xlip(ILK);
        DssEmergencySpellLike spell =
            DssEmergencySpellLike(address(new ClipBreakerSpellV2(dss.chainlog.getAddress("CLIPPER_MOM"), clip, ILK)));
        _elect(address(spell));

        assertFalse(spell.done());
        spell.schedule();
        assertTrue(spell.done());
    }

    function testOsmStopV2OnMainnet() public {
        address osmMom = dss.chainlog.getAddress("OSM_MOM");
        address osm = OsmMomForLeaves(osmMom).osms(ILK);
        DssEmergencySpellLike spell = DssEmergencySpellLike(address(new OsmStopSpellV2(osmMom, osm, ILK)));
        _elect(address(spell));

        assertFalse(spell.done());
        spell.schedule();
        assertTrue(spell.done());
    }

    function testDdmDisableV2OnMainnet() public {
        bytes32 ilk = "DIRECT-SPARK-DAI";
        address plan = DdmHubForLeaves(dss.chainlog.getAddress("DIRECT_HUB")).plan(ilk);
        DssEmergencySpellLike spell =
            DssEmergencySpellLike(address(new DdmDisableSpellV2(dss.chainlog.getAddress("DIRECT_MOM"), plan, ilk)));
        _elect(address(spell));

        assertFalse(spell.done());
        spell.schedule();
        assertTrue(spell.done());
    }

    function testLitePsmHaltV2OnMainnet() public {
        DssEmergencySpellLike spell = DssEmergencySpellLike(
            address(
                new LitePsmHaltSpellV2(
                    dss.chainlog.getAddress("LITE_PSM_MOM"), dss.chainlog.getAddress("MCD_LITE_PSM_USDC_A"), Flow.BOTH
                )
            )
        );
        _elect(address(spell));

        assertFalse(spell.done());
        spell.schedule();
        assertTrue(spell.done());
    }

    function testBatchPreservesChiefAuthorizationOnMainnet() public {
        address clip = IlkRegistryForLeaves(dss.chainlog.getAddress("ILK_REGISTRY")).xlip(ILK);
        address osmMom = dss.chainlog.getAddress("OSM_MOM");
        address osm = OsmMomForLeaves(osmMom).osms(ILK);
        address[] memory leaves = new address[](2);
        leaves[0] = address(new ClipBreakerSpellV2(dss.chainlog.getAddress("CLIPPER_MOM"), clip, ILK));
        leaves[1] = address(new OsmStopSpellV2(osmMom, osm, ILK));
        EmergencySpellBatchV2 batch = new EmergencySpellBatchV2(leaves, "ETH-A clip and oracle stop");
        _elect(address(batch));

        assertFalse(batch.done());
        batch.schedule();
        assertTrue(batch.done());
    }

    function _elect(address spell) internal {
        stdstore.target(chief).sig("hat()").checked_write(spell);
    }
}
