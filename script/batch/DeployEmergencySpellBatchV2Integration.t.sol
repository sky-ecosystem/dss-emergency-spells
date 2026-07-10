// SPDX-FileCopyrightText: © 2026 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {DssTest} from "dss-test/DssTest.sol";

import {
    EmergencySpellBatchFactoryV2DeployScript,
    EmergencySpellBatchV2DeployScript
} from "./DeployEmergencySpellBatchV2.s.sol";
import {EmergencySpellBatchV2} from "../../src/EmergencySpellBatchV2.sol";

contract DeployEmergencySpellBatchV2IntegrationTest is DssTest {
    address internal constant CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;
    bytes32 internal constant EMERGENCY_SPELL_BATCH_FAB = "EMERGENCY_SPELL_BATCH_FAB";

    function setUp() public {
        vm.createSelectFork("mainnet");
    }

    function testPlannedFactoryKeyOnMainnetFork() public {
        address factory = new EmergencySpellBatchFactoryV2DeployScript().run();
        vm.mockCall(
            CHAINLOG, abi.encodeWithSignature("getAddress(bytes32)", EMERGENCY_SPELL_BATCH_FAB), abi.encode(factory)
        );
        address[] memory leaves = new address[](2);
        leaves[0] = address(0x11);
        leaves[1] = address(0x22);
        EmergencySpellBatchV2DeployScript deployer = new EmergencySpellBatchV2DeployScript();
        bytes32 createHash = keccak256(abi.encode(leaves, "Create"));
        bytes32 create2Hash = keccak256(abi.encode(leaves, "Create2"));

        address created = deployer.run(leaves, "Create", createHash);
        address predicted = deployer.preview(leaves, "Create2");
        address deterministic = deployer.runDeterministic(leaves, "Create2", create2Hash);

        assertEq(EmergencySpellBatchV2(created).leaves(), leaves);
        assertEq(deterministic, predicted);
    }
}
