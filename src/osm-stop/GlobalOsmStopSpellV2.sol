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

interface IlkRegistryLike {
    function count() external view returns (uint256);
    function list() external view returns (bytes32[] memory);
    function list(uint256 start, uint256 end) external view returns (bytes32[] memory);
}

interface OsmMomLike {
    function osms(bytes32 ilk) external view returns (address);
    function stop(bytes32 ilk) external;
}

interface OsmLike {
    function stopped() external view returns (uint256);
}

/// @notice Stops every nonzero live OsmMom mapping in the IlkRegistry set.
contract GlobalOsmStopSpellV2 is EmergencySpellV2 {
    string public constant override description = "Emergency Spell | Global OSM Stop";

    address public immutable ilkRegistry;
    address public immutable osmMom;

    event Stop(bytes32 indexed ilk, address indexed osm);

    constructor(address ilkRegistry_, address osmMom_) {
        ilkRegistry = ilkRegistry_;
        osmMom = osmMom_;
    }

    function scheduleRange(uint256 start, uint256 end) external {
        uint256 count = IlkRegistryLike(ilkRegistry).count();
        require(count != 0, "GlobalOsmStopSpellV2/empty-registry");
        require(start < count, "GlobalOsmStopSpellV2/start-out-of-bounds");
        require(start <= end, "GlobalOsmStopSpellV2/invalid-range");
        if (end >= count) end = count - 1;
        _stop(IlkRegistryLike(ilkRegistry).list(start, end));
    }

    function done() external view override returns (bool) {
        bytes32[] memory ilks = IlkRegistryLike(ilkRegistry).list();
        for (uint256 i; i < ilks.length; ++i) {
            address osm = OsmMomLike(osmMom).osms(ilks[i]);
            if (osm == address(0)) continue;
            if (OsmLike(osm).stopped() != 1) return false;
        }
        return true;
    }

    function _emergencyActions() internal override {
        _stop(IlkRegistryLike(ilkRegistry).list());
    }

    function _stop(bytes32[] memory ilks) internal {
        for (uint256 i; i < ilks.length; ++i) {
            bytes32 ilk = ilks[i];
            address osm = OsmMomLike(osmMom).osms(ilk);
            if (osm == address(0)) continue;

            OsmMomLike(osmMom).stop(ilk);
            require(OsmLike(osm).stopped() == 1, "GlobalOsmStopSpellV2/not-stopped");
            emit Stop(ilk, osm);
        }
    }
}
