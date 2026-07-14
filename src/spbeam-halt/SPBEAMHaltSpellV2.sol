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

interface SPBEAMMomLike {
    function halt(address spbeam) external;
}

interface SPBEAMLike {
    function bad() external view returns (uint256);
}

contract SPBEAMHaltSpellV2 is EmergencySpellV2 {
    string public constant override description = "Emergency Spell | Halt SPBEAM";

    address public immutable spbeamMom;
    address public immutable spbeam;

    constructor(address spbeamMom_, address spbeam_) {
        spbeamMom = spbeamMom_;
        spbeam = spbeam_;
    }

    function done() external view override returns (bool) {
        return SPBEAMLike(spbeam).bad() == 1;
    }

    function _emergencyActions() internal override {
        SPBEAMMomLike(spbeamMom).halt(spbeam);
    }
}
