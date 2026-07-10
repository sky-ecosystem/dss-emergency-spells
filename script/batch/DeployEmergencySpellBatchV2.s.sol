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

import {Script} from "forge-std/Script.sol";

import {ChainlogLike} from "../../src/EmergencySpellV2.sol";
import {EmergencySpellBatchFactoryV2} from "../../src/EmergencySpellBatchFactoryV2.sol";

contract EmergencySpellBatchFactoryV2DeployScript is Script {
    function run() external returns (address deployed) {
        vm.broadcast();
        deployed = address(new EmergencySpellBatchFactoryV2());
    }
}

contract EmergencySpellBatchV2DeployScript is Script {
    ChainlogLike internal constant chainlog = ChainlogLike(0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F);

    function run(address factory, address[] calldata leaves, string calldata label, bytes32 expectedConfigHash)
        public
        returns (address deployed)
    {
        require(
            keccak256(abi.encode(leaves, label)) == expectedConfigHash,
            "EmergencySpellBatchV2DeployScript/config-hash-mismatch"
        );
        vm.broadcast();
        deployed = EmergencySpellBatchFactoryV2(factory).deploy(leaves, label);
    }

    function run(address[] calldata leaves, string calldata label, bytes32 expectedConfigHash)
        external
        returns (address deployed)
    {
        deployed = run(chainlog.getAddress("EMERGENCY_SPELL_BATCH_FAB"), leaves, label, expectedConfigHash);
    }

    function runDeterministic(
        address factory,
        address[] calldata leaves,
        string calldata label,
        bytes32 expectedConfigHash
    ) public returns (address deployed) {
        require(
            keccak256(abi.encode(leaves, label)) == expectedConfigHash,
            "EmergencySpellBatchV2DeployScript/config-hash-mismatch"
        );
        vm.broadcast();
        deployed = EmergencySpellBatchFactoryV2(factory).deployDeterministic(leaves, label);
    }

    function runDeterministic(address[] calldata leaves, string calldata label, bytes32 expectedConfigHash)
        external
        returns (address deployed)
    {
        deployed = runDeterministic(chainlog.getAddress("EMERGENCY_SPELL_BATCH_FAB"), leaves, label, expectedConfigHash);
    }

    function preview(address factory, address[] calldata leaves, string calldata label) public view returns (address) {
        return EmergencySpellBatchFactoryV2(factory).previewDeterministicAddress(leaves, label);
    }

    function preview(address[] calldata leaves, string calldata label) external view returns (address) {
        return preview(chainlog.getAddress("EMERGENCY_SPELL_BATCH_FAB"), leaves, label);
    }
}
