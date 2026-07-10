// SPDX-FileCopyrightText: © 2026 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {Test} from "forge-std/Test.sol";

import {EmergencySpellBatchV2} from "./EmergencySpellBatchV2.sol";
import {EmergencySpellBatchFactoryV2} from "./EmergencySpellBatchFactoryV2.sol";
import {BatchLeafV2, BatchTargetV2} from "./EmergencySpellBatchV2.t.sol";

contract EmergencySpellBatchFactoryV2Test is Test {
    address internal constant CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;
    bytes32 internal constant MCD_PAUSE = "MCD_PAUSE";

    EmergencySpellBatchFactoryV2 internal factory;
    BatchLeafV2 internal leafOne;
    BatchLeafV2 internal leafTwo;
    address[] internal selectedLeaves;

    event BatchDeployed(
        address indexed batch, bytes32 indexed configHash, EmergencySpellBatchFactoryV2.DeploymentMode mode
    );

    function setUp() public {
        BatchTargetV2 pause = new BatchTargetV2();
        vm.mockCall(CHAINLOG, abi.encodeWithSignature("getAddress(bytes32)", MCD_PAUSE), abi.encode(address(pause)));

        leafOne = new BatchLeafV2(address(new BatchTargetV2()), 11);
        leafTwo = new BatchLeafV2(address(new BatchTargetV2()), 22);
        selectedLeaves.push(address(leafOne));
        selectedLeaves.push(address(leafTwo));
        factory = new EmergencySpellBatchFactoryV2();
    }

    function testPermissionlessCreateDeployment() public {
        bytes32 configHash = keccak256(abi.encode(selectedLeaves, "Incident batch"));
        address caller = makeAddr("facilitator");

        vm.expectEmit(false, true, false, true, address(factory));
        emit BatchDeployed(address(0), configHash, EmergencySpellBatchFactoryV2.DeploymentMode.CREATE);
        vm.prank(caller);
        address deployed = factory.deploy(selectedLeaves, "Incident batch");

        assertGt(deployed.code.length, 0);
        assertEq(EmergencySpellBatchV2(deployed).leaves(), selectedLeaves);
        assertEq(EmergencySpellBatchV2(deployed).label(), "Incident batch");
        assertEq(EmergencySpellBatchV2(deployed).configHash(), configHash);
    }

    function testCreatePreservesArbitraryOrderAndCanRepeat() public {
        address[] memory reversed = new address[](2);
        reversed[0] = selectedLeaves[1];
        reversed[1] = selectedLeaves[0];

        address first = factory.deploy(reversed, "Ordered action");
        address second = factory.deploy(reversed, "Ordered action");

        assertTrue(first != second);
        assertEq(EmergencySpellBatchV2(first).leaves(), reversed);
        assertEq(EmergencySpellBatchV2(second).leaves(), reversed);
    }

    function testDeterministicPreviewAndDeployment() public {
        address[] memory sorted = _sortedLeaves();
        address predicted = factory.previewDeterministicAddress(sorted, "Planned batch");
        address independentlyCalculated = _independentCreate2Address(sorted, "Planned batch");
        bytes32 configHash = keccak256(abi.encode(sorted, "Planned batch"));

        assertEq(predicted, independentlyCalculated);
        vm.expectEmit(true, true, false, true, address(factory));
        emit BatchDeployed(predicted, configHash, EmergencySpellBatchFactoryV2.DeploymentMode.CREATE2);
        address deployed = factory.deployDeterministic(sorted, "Planned batch");

        assertEq(deployed, predicted);
        assertEq(EmergencySpellBatchV2(deployed).leaves(), sorted);
    }

    function testPreviewAndDeploymentRejectUnsortedLeaves() public {
        address[] memory sorted = _sortedLeaves();
        (sorted[0], sorted[1]) = (sorted[1], sorted[0]);

        vm.expectRevert("EmergencySpellBatchFactoryV2/leaves-not-strictly-ordered");
        factory.previewDeterministicAddress(sorted, "Unsorted");
        vm.expectRevert("EmergencySpellBatchFactoryV2/leaves-not-strictly-ordered");
        factory.deployDeterministic(sorted, "Unsorted");
    }

    function testPreviewAndDeploymentRejectDuplicateLeaves() public {
        address[] memory duplicates = new address[](2);
        duplicates[0] = address(leafOne);
        duplicates[1] = address(leafOne);

        vm.expectRevert("EmergencySpellBatchFactoryV2/leaves-not-strictly-ordered");
        factory.previewDeterministicAddress(duplicates, "Duplicate");
        vm.expectRevert("EmergencySpellBatchFactoryV2/leaves-not-strictly-ordered");
        factory.deployDeterministic(duplicates, "Duplicate");
    }

    function testDuplicateDeterministicDeploymentRevertsWithAddress() public {
        address[] memory sorted = _sortedLeaves();
        address deployed = factory.deployDeterministic(sorted, "Same configuration");

        assertEq(deployed, factory.previewDeterministicAddress(sorted, "Same configuration"));
        vm.expectRevert("EmergencySpellBatchFactoryV2/already-deployed");
        factory.deployDeterministic(sorted, "Same configuration");
    }

    function testLabelChangesDeterministicAddress() public view {
        address[] memory sorted = _sortedLeaves();
        address base = factory.previewDeterministicAddress(sorted, "Label A");
        assertTrue(base != factory.previewDeterministicAddress(sorted, "Label B"));
    }

    function _sortedLeaves() internal view returns (address[] memory sorted) {
        sorted = new address[](2);
        if (address(leafOne) < address(leafTwo)) {
            sorted[0] = address(leafOne);
            sorted[1] = address(leafTwo);
        } else {
            sorted[0] = address(leafTwo);
            sorted[1] = address(leafOne);
        }
    }

    function _independentCreate2Address(address[] memory leaves, string memory label) internal view returns (address) {
        bytes32 salt = keccak256(abi.encode(leaves, label));
        bytes32 initCodeHash =
            keccak256(abi.encodePacked(type(EmergencySpellBatchV2).creationCode, abi.encode(leaves, label)));
        return address(uint160(uint256(keccak256(abi.encodePacked(hex"ff", address(factory), salt, initCodeHash)))));
    }
}
