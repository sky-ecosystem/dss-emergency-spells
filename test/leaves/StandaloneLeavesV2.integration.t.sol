// SPDX-FileCopyrightText: © 2026 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {stdStorage, StdStorage} from "forge-std/Test.sol";
import {DssInstance, DssTest, MCD} from "dss-test/DssTest.sol";

import {EmergencySpellBatchV2} from "../../src/EmergencySpellBatchV2.sol";
import {EmergencySpellLikeV2} from "../../src/EmergencySpellV2.sol";
import {SPBEAMHaltSpellV2} from "../../src/spbeam-halt/SPBEAMHaltSpellV2.sol";
import {SplitterStopSpellV2} from "../../src/splitter-stop/SplitterStopSpellV2.sol";
import {StUsdsRateSetterDissBudSpellV2} from "../../src/stusds/StUsdsRateSetterDissBudSpellV2.sol";
import {StUsdsRateSetterHaltSpellV2} from "../../src/stusds/StUsdsRateSetterHaltSpellV2.sol";
import {StUsdsParamV2, StUsdsWipeParamSpellV2} from "../../src/stusds/StUsdsWipeParamSpellV2.sol";

contract StandaloneLeavesV2IntegrationTest is DssTest {
    using stdStorage for StdStorage;

    address internal constant CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;

    DssInstance internal dss;
    address internal chief;

    function setUp() public {
        vm.createSelectFork("mainnet");
        dss = MCD.loadFromChainlog(CHAINLOG);
        MCD.giveAdminAccess(dss);
        chief = dss.chainlog.getAddress("MCD_ADM");
        vm.makePersistent(chief);
    }

    function testSPBEAMHaltV2OnMainnet() public {
        EmergencySpellLikeV2 spell = EmergencySpellLikeV2(
            address(new SPBEAMHaltSpellV2(dss.chainlog.getAddress("SPBEAM_MOM"), dss.chainlog.getAddress("MCD_SPBEAM")))
        );
        _elect(address(spell));
        assertFalse(spell.done());
        spell.schedule();
        assertTrue(spell.done());
    }

    function testSplitterStopV2OnMainnet() public {
        EmergencySpellLikeV2 spell = EmergencySpellLikeV2(
            address(
                new SplitterStopSpellV2(dss.chainlog.getAddress("SPLITTER_MOM"), dss.chainlog.getAddress("MCD_SPLIT"))
            )
        );
        _elect(address(spell));
        assertFalse(spell.done());
        spell.schedule();
        assertTrue(spell.done());
    }

    function testStUsdsRateSetterDissBudV2OnMainnet() public {
        address rateSetter = dss.chainlog.getAddress("STUSDS_RATE_SETTER");
        address bud = makeAddr("bud");
        stdstore.target(rateSetter).sig("buds(address)").with_key(bud).checked_write(uint256(1));
        EmergencySpellLikeV2 spell = EmergencySpellLikeV2(
            address(new StUsdsRateSetterDissBudSpellV2(dss.chainlog.getAddress("STUSDS_MOM"), rateSetter, bud))
        );
        _elect(address(spell));
        assertFalse(spell.done());
        spell.schedule();
        assertTrue(spell.done());
    }

    function testStUsdsRateSetterHaltV2OnMainnet() public {
        EmergencySpellLikeV2 spell = EmergencySpellLikeV2(
            address(
                new StUsdsRateSetterHaltSpellV2(
                    dss.chainlog.getAddress("STUSDS_MOM"), dss.chainlog.getAddress("STUSDS_RATE_SETTER")
                )
            )
        );
        _elect(address(spell));
        assertFalse(spell.done());
        spell.schedule();
        assertTrue(spell.done());
    }

    function testStUsdsWipeParamV2OnMainnet() public {
        address stUsds = dss.chainlog.getAddress("STUSDS");
        address rateSetter = dss.chainlog.getAddress("STUSDS_RATE_SETTER");
        stdstore.target(stUsds).sig("line()").checked_write(1_000_000 * RAD);
        stdstore.target(stUsds).sig("cap()").checked_write(1_000_000 * WAD);
        stdstore.target(rateSetter).sig("maxLine()").checked_write(1_000_000 * RAD);
        stdstore.target(rateSetter).sig("maxCap()").checked_write(1_000_000 * WAD);
        EmergencySpellLikeV2 spell = EmergencySpellLikeV2(
            address(
                new StUsdsWipeParamSpellV2(
                    dss.chainlog.getAddress("STUSDS_MOM"), rateSetter, stUsds, StUsdsParamV2.BOTH
                )
            )
        );
        _elect(address(spell));
        assertFalse(spell.done());
        spell.schedule();
        assertTrue(spell.done());
    }

    function testBatchPreservesChiefAuthorizationOnMainnet() public {
        address[] memory leaves = new address[](2);
        leaves[0] = address(
            new SPBEAMHaltSpellV2(dss.chainlog.getAddress("SPBEAM_MOM"), dss.chainlog.getAddress("MCD_SPBEAM"))
        );
        leaves[1] = address(
            new SplitterStopSpellV2(dss.chainlog.getAddress("SPLITTER_MOM"), dss.chainlog.getAddress("MCD_SPLIT"))
        );
        EmergencySpellBatchV2 batch = new EmergencySpellBatchV2(leaves, "SPBEAM and Splitter stop");
        _elect(address(batch));
        assertFalse(batch.done());
        batch.schedule();
        assertTrue(batch.done());
    }

    function _elect(address spell) internal {
        stdstore.target(chief).sig("hat()").checked_write(spell);
    }
}
