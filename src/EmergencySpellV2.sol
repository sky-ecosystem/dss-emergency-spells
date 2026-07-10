// SPDX-FileCopyrightText: © 2026 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

interface ChainlogLike {
    function getAddress(bytes32 key) external view returns (address);
}

interface DssExec {
    function action() external view returns (address);
    function cast() external;
    function description() external view returns (string memory);
    function done() external view returns (bool);
    function eta() external view returns (uint256);
    function expiration() external view returns (uint256);
    function log() external view returns (address);
    function nextCastTime() external view returns (uint256);
    function officeHours() external view returns (bool);
    function pause() external view returns (address);
    function schedule() external;
    function sig() external view returns (bytes memory);
    function tag() external view returns (bytes32);
}

interface DssAction {
    function actions() external;
    function description() external view returns (string memory);
    function execute() external;
    function nextCastTime(uint256 eta) external view returns (uint256);
    function officeHours() external view returns (bool);
}

interface DssEmergencySpellLike is DssExec, DssAction {
    function description() external view override(DssExec, DssAction) returns (string memory);
    function officeHours() external view override(DssExec, DssAction) returns (bool);
}

/// @notice Compatibility surface shared by V2 Emergency Spells.
/// @dev Batch-eligible descendants must keep their execution paths free of normal storage reads and writes.
abstract contract EmergencySpellV2 is DssEmergencySpellLike {
    ChainlogLike internal constant _log = ChainlogLike(0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F);

    address public immutable override pause;
    address public constant override log = address(_log);
    uint256 public constant override eta = 0;
    bytes public constant override sig = abi.encodeWithSelector(DssAction.execute.selector);
    uint256 public constant override expiration = type(uint256).max;
    bool public constant override officeHours = false;
    address public immutable override action;
    uint256 internal immutable _nextCastTime = type(uint256).max;

    constructor() {
        pause = _log.getAddress("MCD_PAUSE");
        action = address(this);
    }

    /// @return The runtime codehash of the spell when called directly.
    function tag() external view override returns (bytes32) {
        return address(this).codehash;
    }

    /// @notice Executes the emergency action immediately without the GSM delay.
    function schedule() external override {
        _emergencyActions();
    }

    function _emergencyActions() internal virtual;

    function nextCastTime() external view override returns (uint256) {
        return _nextCastTime;
    }

    function nextCastTime(uint256) external view override returns (uint256) {
        return _nextCastTime;
    }

    function cast() external override {}

    function execute() external override {}

    function actions() external override {}
}
