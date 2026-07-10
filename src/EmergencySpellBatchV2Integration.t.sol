// SPDX-FileCopyrightText: © 2026 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {stdStorage, StdStorage} from "forge-std/Test.sol";
import {DssInstance, DssTest, MCD} from "dss-test/DssTest.sol";

import {EmergencySpellBatchV2} from "./EmergencySpellBatchV2.sol";
import {ClipBreakerSpellV2} from "./clip-breaker/ClipBreakerSpellV2.sol";
import {OsmStopSpellV2} from "./osm-stop/OsmStopSpellV2.sol";
import {SPBEAMHaltSpellV2} from "./spbeam-halt/SPBEAMHaltSpellV2.sol";
import {SplitterStopSpellV2} from "./splitter-stop/SplitterStopSpellV2.sol";

interface IlkRegistryForBatch {
    function xlip(bytes32 ilk) external view returns (address);
}

interface OsmMomForBatch {
    function osms(bytes32 ilk) external view returns (address);
}

contract EmergencySpellBatchV2IntegrationTest is DssTest {
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

    function testBatchPreservesChiefAuthorizationForCoreLeavesOnMainnet() public {
        address clip = IlkRegistryForBatch(dss.chainlog.getAddress("ILK_REGISTRY")).xlip(ILK);
        address osmMom = dss.chainlog.getAddress("OSM_MOM");
        address osm = OsmMomForBatch(osmMom).osms(ILK);
        address[] memory leaves = new address[](2);
        leaves[0] = address(new ClipBreakerSpellV2(dss.chainlog.getAddress("CLIPPER_MOM"), clip, ILK));
        leaves[1] = address(new OsmStopSpellV2(osmMom, osm, ILK));
        EmergencySpellBatchV2 batch = new EmergencySpellBatchV2(leaves, "ETH-A clip and oracle stop");
        stdstore.target(chief).sig("hat()").checked_write(address(batch));

        assertFalse(batch.done());
        batch.schedule();
        assertTrue(batch.done());
    }

    function testBatchPreservesChiefAuthorizationForStandaloneLeavesOnMainnet() public {
        address[] memory leaves = new address[](2);
        leaves[0] = address(
            new SPBEAMHaltSpellV2(dss.chainlog.getAddress("SPBEAM_MOM"), dss.chainlog.getAddress("MCD_SPBEAM"))
        );
        leaves[1] = address(
            new SplitterStopSpellV2(dss.chainlog.getAddress("SPLITTER_MOM"), dss.chainlog.getAddress("MCD_SPLIT"))
        );
        EmergencySpellBatchV2 batch = new EmergencySpellBatchV2(leaves, "SPBEAM and Splitter stop");
        stdstore.target(chief).sig("hat()").checked_write(address(batch));

        assertFalse(batch.done());
        batch.schedule();
        assertTrue(batch.done());
    }
}
