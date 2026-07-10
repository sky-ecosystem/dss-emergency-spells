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

import {EmergencySpellBatchV2} from "./EmergencySpellBatchV2.sol";

/// @notice Permissionless deployment utility for V2 Batch Emergency Spells.
contract EmergencySpellBatchFactoryV2 {
    enum DeploymentMode {
        CREATE,
        CREATE2
    }

    event BatchDeployed(address indexed batch, bytes32 indexed configHash, DeploymentMode mode);

    function deploy(address[] calldata leaves, string calldata label) external returns (address batch) {
        bytes32 configHash = _configHash(leaves, label);
        batch = address(new EmergencySpellBatchV2(leaves, label));
        emit BatchDeployed(batch, configHash, DeploymentMode.CREATE);
    }

    function deployDeterministic(address[] calldata leaves, string calldata label) external returns (address batch) {
        _requireStrictlyOrdered(leaves);
        bytes32 configHash = _configHash(leaves, label);
        bytes32 initCodeHash =
            keccak256(abi.encodePacked(type(EmergencySpellBatchV2).creationCode, abi.encode(leaves, label)));
        address predicted =
            address(uint160(uint256(keccak256(abi.encodePacked(hex"ff", address(this), configHash, initCodeHash)))));
        require(predicted.code.length == 0, "EmergencySpellBatchFactoryV2/already-deployed");

        batch = address(new EmergencySpellBatchV2{salt: configHash}(leaves, label));
        emit BatchDeployed(batch, configHash, DeploymentMode.CREATE2);
    }

    function previewDeterministicAddress(address[] calldata leaves, string calldata label)
        external
        view
        returns (address)
    {
        _requireStrictlyOrdered(leaves);
        bytes32 configHash = _configHash(leaves, label);
        bytes32 initCodeHash =
            keccak256(abi.encodePacked(type(EmergencySpellBatchV2).creationCode, abi.encode(leaves, label)));
        return address(uint160(uint256(keccak256(abi.encodePacked(hex"ff", address(this), configHash, initCodeHash)))));
    }

    function _configHash(address[] calldata leaves, string calldata label) internal pure returns (bytes32) {
        return keccak256(abi.encode(leaves, label));
    }

    function _requireStrictlyOrdered(address[] calldata leaves) internal pure {
        for (uint256 i = 1; i < leaves.length; ++i) {
            address previous = leaves[i - 1];
            address current = leaves[i];
            require(previous < current, "EmergencySpellBatchFactoryV2/leaves-not-strictly-ordered");
        }
    }
}
