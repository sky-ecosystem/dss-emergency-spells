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
    event BatchDeployed(address indexed batch, bytes32 indexed configHash);

    function deploy(address[] calldata leaves, string calldata label) external returns (address batch) {
        bytes32 configHash = _configHash(leaves, label);
        batch = address(new EmergencySpellBatchV2(leaves, label));
        emit BatchDeployed(batch, configHash);
    }

    function _configHash(address[] calldata leaves, string calldata label) internal pure returns (bytes32) {
        return keccak256(abi.encode(leaves, label));
    }
}
