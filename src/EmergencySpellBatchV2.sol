// SPDX-FileCopyrightText: © 2026 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

pragma solidity ^0.8.16;

import {DssEmergencySpellLike, DssExec, EmergencySpellV2} from "./EmergencySpellV2.sol";

/// @notice Executes an ordered set of reviewed Emergency Spell leaves atomically through delegatecall.
/// @dev This contract uses normal storage and is direct-use only. It must never be selected as a batch leaf.
contract EmergencySpellBatchV2 is EmergencySpellV2 {
    bytes32 public immutable configHash;

    address[] private _leaves;
    string public label;

    event LeafExecuted(uint256 indexed index, address indexed leaf);

    constructor(address[] memory leaves_, string memory label_) {
        require(leaves_.length != 0, "EmergencySpellBatchV2/empty-leaf-set");
        require(bytes(label_).length != 0, "EmergencySpellBatchV2/empty-label");

        for (uint256 i; i < leaves_.length; ++i) {
            address leaf = leaves_[i];
            for (uint256 j; j < i; ++j) {
                require(leaf != leaves_[j], "EmergencySpellBatchV2/duplicate-leaf");
            }
            _leaves.push(leaf);
        }

        label = label_;
        configHash = keccak256(abi.encode(leaves_, label_));
    }

    function description() external view override returns (string memory) {
        return string.concat("Emergency Spell | Batch: ", label);
    }

    function leaves() external view returns (address[] memory) {
        return _leaves;
    }

    function done() external view override returns (bool) {
        for (uint256 i; i < _leaves.length; ++i) {
            if (!DssEmergencySpellLike(_leaves[i]).done()) return false;
        }
        return true;
    }

    function _emergencyActions() internal override {
        address[] memory selectedLeaves = _leaves;
        bytes memory scheduleCall = abi.encodeCall(DssExec.schedule, ());

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
