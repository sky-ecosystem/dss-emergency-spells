// SPDX-FileCopyrightText: © 2026 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {Test} from "forge-std/Test.sol";

import {
    EmergencySpellBatchFactoryV2DeployScript,
    EmergencySpellBatchV2DeployScript
} from "./DeployEmergencySpellBatchV2.s.sol";
import {EmergencySpellBatchV2} from "../../src/EmergencySpellBatchV2.sol";

contract DeployEmergencySpellBatchV2Test is Test {
    address internal constant CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;

    function setUp() public {
        _mockChainlog("MCD_PAUSE", address(1));
    }

    function testExplicitAndChainlogFactoryEntrypoints() public {
        address factory = new EmergencySpellBatchFactoryV2DeployScript().run();
        _mockChainlog("EMERGENCY_SPELL_BATCH_FAB", factory);
        address[] memory leaves = new address[](2);
        leaves[0] = address(0x11);
        leaves[1] = address(0x22);
        EmergencySpellBatchV2DeployScript deployer = new EmergencySpellBatchV2DeployScript();
        bytes32 createHash = keccak256(abi.encode(leaves, "Create"));

        address created = deployer.run(leaves, "Create", createHash);

        assertEq(EmergencySpellBatchV2(created).leaves(), leaves);

        vm.expectRevert("EmergencySpellBatchV2DeployScript/config-hash-mismatch");
        deployer.run(factory, leaves, "Wrong", createHash);
    }

    function _mockChainlog(bytes32 key, address value) internal {
        vm.mockCall(CHAINLOG, abi.encodeWithSignature("getAddress(bytes32)", key), abi.encode(value));
    }
}
