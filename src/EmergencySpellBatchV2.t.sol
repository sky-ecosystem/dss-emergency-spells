// SPDX-FileCopyrightText: © 2026 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";

import {EmergencySpellBatchV2} from "./EmergencySpellBatchV2.sol";
import {EmergencySpellV2} from "./EmergencySpellV2.sol";

contract BatchTargetV2 {
    uint256 public value;
    address public caller;

    event ValueSet(uint256 value, address caller);

    function setValue(uint256 value_) external {
        value = value_;
        caller = msg.sender;
        emit ValueSet(value_, msg.sender);
    }
}

contract BatchLeafV2 is EmergencySpellV2 {
    BatchTargetV2 public immutable target;
    uint256 public immutable value;

    constructor(address target_, uint256 value_) {
        target = BatchTargetV2(target_);
        value = value_;
    }

    function description() external pure override returns (string memory) {
        return "Emergency Spell | Test Leaf";
    }

    function done() external view override returns (bool) {
        return target.value() == value;
    }

    function _emergencyActions() internal override {
        target.setValue(value);
    }
}

contract RevertingBatchLeafV2 is EmergencySpellV2 {
    error LeafFailure(uint256 reason);

    uint256 public immutable reason;

    constructor(uint256 reason_) {
        reason = reason_;
    }

    function description() external pure override returns (string memory) {
        return "Emergency Spell | Reverting Test Leaf";
    }

    function done() external pure override returns (bool) {
        return false;
    }

    function _emergencyActions() internal view override {
        revert LeafFailure(reason);
    }
}

contract EmergencySpellBatchV2Test is Test {
    address internal constant CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;
    bytes32 internal constant MCD_PAUSE = "MCD_PAUSE";
    bytes32 internal constant LEAF_EXECUTED_SIG = keccak256("LeafExecuted(uint256,address)");

    BatchTargetV2 internal pause;
    BatchTargetV2 internal targetOne;
    BatchTargetV2 internal targetTwo;
    BatchLeafV2 internal leafOne;
    BatchLeafV2 internal leafTwo;
    address[] internal selectedLeaves;
    EmergencySpellBatchV2 internal batch;

    function setUp() public {
        pause = new BatchTargetV2();
        vm.mockCall(CHAINLOG, abi.encodeWithSignature("getAddress(bytes32)", MCD_PAUSE), abi.encode(address(pause)));

        targetOne = new BatchTargetV2();
        targetTwo = new BatchTargetV2();
        leafOne = new BatchLeafV2(address(targetOne), 11);
        leafTwo = new BatchLeafV2(address(targetTwo), 22);

        selectedLeaves.push(address(leafOne));
        selectedLeaves.push(address(leafTwo));
        batch = new EmergencySpellBatchV2(selectedLeaves, "Core response");
    }

    function testMetadataPreservesReviewedOrder() public view {
        address[] memory leaves = batch.leaves();

        assertEq(leaves, selectedLeaves);
        assertEq(batch.label(), "Core response");
        assertEq(batch.description(), "Emergency Spell | Batch: Core response");
        assertEq(batch.configHash(), keccak256(abi.encode(selectedLeaves, "Core response")));
    }

    function testDoneRequiresEveryLeafEndState() public {
        assertFalse(batch.done());

        leafOne.schedule();
        assertFalse(batch.done());

        leafTwo.schedule();
        assertTrue(batch.done());
    }

    function testScheduleRunsLeavesThroughBatchAddressInOrder() public {
        address chiefCaller = makeAddr("chief-hat-caller");
        vm.recordLogs();

        vm.prank(chiefCaller);
        batch.schedule();

        assertEq(targetOne.value(), 11);
        assertEq(targetTwo.value(), 22);
        assertEq(targetOne.caller(), address(batch));
        assertEq(targetTwo.caller(), address(batch));

        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 executionIndex;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter != address(batch) || logs[i].topics[0] != LEAF_EXECUTED_SIG) continue;

            assertEq(uint256(logs[i].topics[1]), executionIndex);
            assertEq(address(uint160(uint256(logs[i].topics[2]))), selectedLeaves[executionIndex]);
            ++executionIndex;
        }
        assertEq(executionIndex, selectedLeaves.length);
        assertTrue(batch.done());
    }

    function testRevertDataIsBubbledAndEarlierEffectsRollBack() public {
        RevertingBatchLeafV2 revertingLeaf = new RevertingBatchLeafV2(42);
        address[] memory leaves = new address[](2);
        leaves[0] = address(leafOne);
        leaves[1] = address(revertingLeaf);
        EmergencySpellBatchV2 revertingBatch = new EmergencySpellBatchV2(leaves, "Atomic rollback");
        bytes memory expectedRevert = abi.encodeWithSelector(RevertingBatchLeafV2.LeafFailure.selector, 42);

        (bool success, bytes memory result) = address(revertingBatch).call(abi.encodeCall(revertingBatch.schedule, ()));

        assertFalse(success);
        assertEq(result, expectedRevert);
        assertEq(targetOne.value(), 0);
    }

    function testDoneBubblesLeafFailure() public {
        RevertingDoneLeafV2 revertingDoneLeaf = new RevertingDoneLeafV2();
        address[] memory leaves = new address[](1);
        leaves[0] = address(revertingDoneLeaf);
        EmergencySpellBatchV2 revertingBatch = new EmergencySpellBatchV2(leaves, "Done failure");

        vm.expectRevert(RevertingDoneLeafV2.DoneFailure.selector);
        revertingBatch.done();
    }

    function testRejectsEmptyLeafSet() public {
        address[] memory leaves = new address[](0);

        vm.expectRevert("EmergencySpellBatchV2/empty-leaf-set");
        new EmergencySpellBatchV2(leaves, "Empty");
    }

    function testRejectsEmptyLabel() public {
        vm.expectRevert("EmergencySpellBatchV2/empty-label");
        new EmergencySpellBatchV2(selectedLeaves, "");
    }

    function testDoesNotValidateLeafAddresses() public {
        address[] memory leaves = new address[](2);
        leaves[0] = address(0);
        leaves[1] = makeAddr("eoa-leaf");

        EmergencySpellBatchV2 arbitraryBatch = new EmergencySpellBatchV2(leaves, "Arbitrary leaves");

        assertEq(arbitraryBatch.leaves(), leaves);
    }

    function testRejectsDuplicateLeaf() public {
        address[] memory leaves = new address[](2);
        leaves[0] = address(leafOne);
        leaves[1] = address(leafOne);

        vm.expectRevert("EmergencySpellBatchV2/duplicate-leaf");
        new EmergencySpellBatchV2(leaves, "Duplicate");
    }
}

contract RevertingDoneLeafV2 is EmergencySpellV2 {
    error DoneFailure();

    function description() external pure override returns (string memory) {
        return "Emergency Spell | Reverting Done Leaf";
    }

    function done() external pure override returns (bool) {
        revert DoneFailure();
    }

    function _emergencyActions() internal override {}
}
