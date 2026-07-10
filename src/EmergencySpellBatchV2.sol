// SPDX-FileCopyrightText: © 2026 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {DssExecLikeV2, EmergencySpellLikeV2, EmergencySpellV2} from "./EmergencySpellV2.sol";

/// @notice Executes an ordered set of reviewed Emergency Spell leaves atomically through delegatecall.
/// @dev This contract uses normal storage and is direct-use only. It must never be selected as a batch leaf.
contract EmergencySpellBatchV2 is EmergencySpellV2 {
    error DuplicateLeaf(address leaf);
    error EmptyLabel();
    error EmptyLeafSet();

    event LeafExecuted(uint256 indexed index, address indexed leaf);

    address[] private _leaves;
    string private _label;

    bytes32 public immutable configHash;

    constructor(address[] memory leaves_, string memory label_) {
        if (leaves_.length == 0) revert EmptyLeafSet();
        if (bytes(label_).length == 0) revert EmptyLabel();

        for (uint256 i; i < leaves_.length; ++i) {
            address leaf = _requireContract(leaves_[i]);
            for (uint256 j; j < i; ++j) {
                if (leaf == leaves_[j]) revert DuplicateLeaf(leaf);
            }
            _leaves.push(leaf);
        }

        _label = label_;
        configHash = keccak256(abi.encode(leaves_, label_));
    }

    function description() external view override returns (string memory) {
        return string.concat("Emergency Spell | Batch: ", _label);
    }

    function label() external view returns (string memory) {
        return _label;
    }

    function leaves() external view returns (address[] memory) {
        return _leaves;
    }

    function done() external view override returns (bool) {
        for (uint256 i; i < _leaves.length; ++i) {
            if (!EmergencySpellLikeV2(_leaves[i]).done()) return false;
        }
        return true;
    }

    function _emergencyActions() internal override {
        address[] memory selectedLeaves = _leaves;
        bytes memory scheduleCall = abi.encodeCall(DssExecLikeV2.schedule, ());

        for (uint256 i; i < selectedLeaves.length; ++i) {
            address leaf = selectedLeaves[i];
            (bool success, bytes memory result) = leaf.delegatecall(scheduleCall);
            if (!success) {
                assembly {
                    revert(add(result, 0x20), mload(result))
                }
            }
            emit LeafExecuted(i, leaf);
        }
    }
}
