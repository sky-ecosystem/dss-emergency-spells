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

interface OsmMomLike {
    function osms(bytes32 ilk) external view returns (address);
    function stop(bytes32 ilk) external;
}

interface OsmLike {
    function stopped() external view returns (uint256);
}

/// @notice Stops one explicitly selected OSM while pinning its expected OsmMom registration.
contract OsmStopSpellV2 is EmergencySpellV2 {
    address public immutable osmMom;
    address public immutable osm;
    bytes32 public immutable ilk;

    constructor(address osmMom_, address osm_, bytes32 ilk_) {
        osmMom = osmMom_;
        osm = osm_;
        ilk = ilk_;
    }

    function description() external view override returns (string memory) {
        return string(abi.encodePacked("Emergency Spell | OSM Stop: ", ilk));
    }

    function done() external view override returns (bool) {
        return OsmLike(osm).stopped() == 1;
    }

    function _emergencyActions() internal override {
        address registered = OsmMomLike(osmMom).osms(ilk);
        require(registered == osm, "OsmStopSpellV2/osm-mismatch");

        OsmMomLike(osmMom).stop(ilk);
    }
}
