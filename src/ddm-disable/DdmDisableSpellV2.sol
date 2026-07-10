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

import {EmergencySpellV2} from "../EmergencySpellV2.sol";

interface DdmMomLike {
    function disable(address plan) external;
}

interface DdmPlanLike {
    function active() external view returns (bool);
}

/// @notice Disables one explicitly selected Direct Deposit Module plan.
contract DdmDisableSpellV2 is EmergencySpellV2 {
    address public immutable ddmMom;
    address public immutable plan;
    bytes32 public immutable ilk;

    event Disable(address indexed plan);

    constructor(address ddmMom_, address plan_, bytes32 ilk_) {
        ddmMom = ddmMom_;
        plan = plan_;
        ilk = ilk_;
    }

    function description() external view override returns (string memory) {
        return string(abi.encodePacked("Emergency Spell | Disable DDM Plan: ", ilk));
    }

    function done() external view override returns (bool) {
        return !DdmPlanLike(plan).active();
    }

    function _emergencyActions() internal override {
        DdmMomLike(ddmMom).disable(plan);
        emit Disable(plan);
    }
}
