// SPDX-FileCopyrightText: © 2026 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {EmergencySpellV2} from "../EmergencySpellV2.sol";
import {DescriptionLibV2} from "../libraries/DescriptionLibV2.sol";

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

    event Stop(address indexed osm);

    constructor(address osmMom_, address osm_, bytes32 ilk_) {
        osmMom = osmMom_;
        osm = osm_;
        ilk = ilk_;
    }

    function description() external view override returns (string memory) {
        return string.concat("Emergency Spell | OSM Stop: ", DescriptionLibV2.toString(ilk));
    }

    function done() external view override returns (bool) {
        return OsmLike(osm).stopped() == 1;
    }

    function _emergencyActions() internal override {
        address registered = OsmMomLike(osmMom).osms(ilk);
        require(registered == osm, "OsmStopSpellV2/osm-mismatch");

        OsmMomLike(osmMom).stop(ilk);
        emit Stop(osm);
    }
}
