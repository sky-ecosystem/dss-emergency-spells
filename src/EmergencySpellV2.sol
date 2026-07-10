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

interface ChainlogLike {
    function getAddress(bytes32 key) external view returns (address);
}

interface DssEmergencySpellLike {
    // DssExec-compatible surface.
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

    // DssAction-compatible additions. description() and officeHours() are shared with DssExec.
    function actions() external;
    function execute() external;
    function nextCastTime(uint256 eta) external view returns (uint256);
}

/// @notice Compatibility surface shared by V2 Emergency Spells.
/// @dev Batch-eligible descendants must keep their execution paths free of normal storage reads and writes.
abstract contract EmergencySpellV2 is DssEmergencySpellLike {
    ChainlogLike internal constant _log = ChainlogLike(0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F);
    address public constant override log = address(_log);

    uint256 public constant override eta = 0;
    bytes public constant override sig = abi.encodeWithSelector(DssEmergencySpellLike.execute.selector);
    uint256 public constant override expiration = type(uint256).max;
    uint256 internal constant _nextCastTime = type(uint256).max;
    bool public constant override officeHours = false;

    address public immutable override pause;
    address public immutable override action;

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
