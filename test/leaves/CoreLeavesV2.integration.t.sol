// SPDX-FileCopyrightText: © 2026 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {stdStorage, StdStorage} from "forge-std/Test.sol";
import {DssInstance, DssTest, MCD} from "dss-test/DssTest.sol";

import {SingleClipBreakerSpellV2} from "../../src/clip-breaker/SingleClipBreakerSpellV2.sol";
import {SingleDdmDisableSpellV2} from "../../src/ddm-disable/SingleDdmDisableSpellV2.sol";
import {EmergencySpellBatchV2} from "../../src/EmergencySpellBatchV2.sol";
import {EmergencySpellLikeV2} from "../../src/EmergencySpellV2.sol";
import {SingleLineWipeSpellV2} from "../../src/line-wipe/SingleLineWipeSpellV2.sol";
import {FlowV2, SingleLitePsmHaltSpellV2} from "../../src/lite-psm-halt/SingleLitePsmHaltSpellV2.sol";
import {SingleOsmStopSpellV2} from "../../src/osm-stop/SingleOsmStopSpellV2.sol";

interface IlkRegistryForLeavesV2 {
    function xlip(bytes32 ilk) external view returns (address);
}

interface OsmMomForLeavesV2 {
    function osms(bytes32 ilk) external view returns (address);
}

interface DdmHubForLeavesV2 {
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

    function testSingleLineWipeV2OnMainnet() public {
        EmergencySpellLikeV2 spell =
            EmergencySpellLikeV2(address(new SingleLineWipeSpellV2(dss.chainlog.getAddress("LINE_MOM"), ILK)));
        _elect(address(spell));

        assertFalse(spell.done());
        spell.schedule();
        assertTrue(spell.done());
    }

    function testSingleClipBreakerV2OnMainnet() public {
        address clip = IlkRegistryForLeavesV2(dss.chainlog.getAddress("ILK_REGISTRY")).xlip(ILK);
        EmergencySpellLikeV2 spell = EmergencySpellLikeV2(
            address(new SingleClipBreakerSpellV2(dss.chainlog.getAddress("CLIPPER_MOM"), clip, ILK))
        );
        _elect(address(spell));

        assertFalse(spell.done());
        spell.schedule();
        assertTrue(spell.done());
    }

    function testSingleOsmStopV2OnMainnet() public {
        address osmMom = dss.chainlog.getAddress("OSM_MOM");
        address osm = OsmMomForLeavesV2(osmMom).osms(ILK);
        EmergencySpellLikeV2 spell = EmergencySpellLikeV2(address(new SingleOsmStopSpellV2(osmMom, osm, ILK)));
        _elect(address(spell));

        assertFalse(spell.done());
        spell.schedule();
        assertTrue(spell.done());
    }

    function testSingleDdmDisableV2OnMainnet() public {
        bytes32 ilk = "DIRECT-SPARK-DAI";
        address plan = DdmHubForLeavesV2(dss.chainlog.getAddress("DIRECT_HUB")).plan(ilk);
        EmergencySpellLikeV2 spell = EmergencySpellLikeV2(
            address(new SingleDdmDisableSpellV2(dss.chainlog.getAddress("DIRECT_MOM"), plan, ilk))
        );
        _elect(address(spell));

        assertFalse(spell.done());
        spell.schedule();
        assertTrue(spell.done());
    }

    function testSingleLitePsmHaltV2OnMainnet() public {
        EmergencySpellLikeV2 spell = EmergencySpellLikeV2(
            address(
                new SingleLitePsmHaltSpellV2(
                    dss.chainlog.getAddress("LITE_PSM_MOM"), dss.chainlog.getAddress("MCD_LITE_PSM_USDC_A"), FlowV2.BOTH
                )
            )
        );
        _elect(address(spell));

        assertFalse(spell.done());
        spell.schedule();
        assertTrue(spell.done());
    }

    function testBatchPreservesChiefAuthorizationOnMainnet() public {
        address clip = IlkRegistryForLeavesV2(dss.chainlog.getAddress("ILK_REGISTRY")).xlip(ILK);
        address osmMom = dss.chainlog.getAddress("OSM_MOM");
        address osm = OsmMomForLeavesV2(osmMom).osms(ILK);
        address[] memory leaves = new address[](2);
        leaves[0] = address(new SingleClipBreakerSpellV2(dss.chainlog.getAddress("CLIPPER_MOM"), clip, ILK));
        leaves[1] = address(new SingleOsmStopSpellV2(osmMom, osm, ILK));
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
