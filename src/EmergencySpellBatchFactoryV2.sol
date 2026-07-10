// SPDX-FileCopyrightText: © 2026 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {EmergencySpellBatchV2} from "./EmergencySpellBatchV2.sol";

/// @notice Permissionless deployment utility for V2 Batch Emergency Spells.
contract EmergencySpellBatchFactoryV2 {
    enum DeploymentMode {
        Create,
        Create2Explicit,
        Create2Sorted
    }

    error BatchAlreadyDeployed(address batch);
    error LeavesNotStrictlyIncreasing(uint256 index, address previous, address current);

    event BatchDeployed(address indexed batch, bytes32 indexed configHash, DeploymentMode mode);

    function deploy(address[] calldata leaves, string calldata label) external returns (address batch) {
        bytes32 configHash = _configHash(leaves, label);
        batch = address(new EmergencySpellBatchV2(leaves, label));
        emit BatchDeployed(batch, configHash, DeploymentMode.Create);
    }

    function deployDeterministic(address[] calldata leaves, string calldata label) external returns (address batch) {
        return _deployDeterministic(leaves, label, DeploymentMode.Create2Explicit);
    }

    function deployDeterministicSorted(address[] calldata leaves, string calldata label)
        external
        returns (address batch)
    {
        _requireStrictlyIncreasing(leaves);
        return _deployDeterministic(leaves, label, DeploymentMode.Create2Sorted);
    }

    function predictDeterministicAddress(address[] calldata leaves, string calldata label)
        external
        view
        returns (address)
    {
        return _predictDeterministicAddress(leaves, label);
    }

    function predictDeterministicSortedAddress(address[] calldata leaves, string calldata label)
        external
        view
        returns (address)
    {
        _requireStrictlyIncreasing(leaves);
        return _predictDeterministicAddress(leaves, label);
    }

    function _deployDeterministic(address[] calldata leaves, string calldata label, DeploymentMode mode)
        internal
        returns (address batch)
    {
        bytes32 configHash = _configHash(leaves, label);
        address predicted = _predictDeterministicAddress(leaves, label);
        if (predicted.code.length != 0) revert BatchAlreadyDeployed(predicted);

        batch = address(new EmergencySpellBatchV2{salt: configHash}(leaves, label));
        emit BatchDeployed(batch, configHash, mode);
    }

    function _predictDeterministicAddress(address[] calldata leaves, string calldata label)
        internal
        view
        returns (address)
    {
        bytes32 configHash = _configHash(leaves, label);
        bytes32 initCodeHash =
            keccak256(abi.encodePacked(type(EmergencySpellBatchV2).creationCode, abi.encode(leaves, label)));
        return address(uint160(uint256(keccak256(abi.encodePacked(hex"ff", address(this), configHash, initCodeHash)))));
    }

    function _configHash(address[] calldata leaves, string calldata label) internal pure returns (bytes32) {
        return keccak256(abi.encode(leaves, label));
    }

    function _requireStrictlyIncreasing(address[] calldata leaves) internal pure {
        for (uint256 i = 1; i < leaves.length; ++i) {
            address previous = leaves[i - 1];
            address current = leaves[i];
            if (previous >= current) revert LeavesNotStrictlyIncreasing(i, previous, current);
        }
    }
}
