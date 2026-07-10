// SPDX-FileCopyrightText: © 2026 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {EmergencySpellV2} from "../EmergencySpellV2.sol";
import {DescriptionLibV2} from "../libraries/DescriptionLibV2.sol";

interface OsmMomLikeV2 {
    function osms(bytes32 ilk) external view returns (address);
    function stop(bytes32 ilk) external;
}

interface OsmLikeV2 {
    function stopped() external view returns (uint256);
}

/// @notice Stops one explicitly selected OSM while pinning its expected OsmMom registration.
contract SingleOsmStopSpellV2 is EmergencySpellV2 {
    error OsmMismatch(address expected, address actual);

    OsmMomLikeV2 public immutable osmMom;
    OsmLikeV2 public immutable osm;
    bytes32 public immutable ilk;

    event Stop(address indexed osm);

    constructor(address osmMom_, address osm_, bytes32 ilk_) {
        osmMom = OsmMomLikeV2(_requireContract(osmMom_));
        osm = OsmLikeV2(_requireContract(osm_));
        ilk = ilk_;
    }

    function description() external view override returns (string memory) {
        return string.concat("Emergency Spell | OSM Stop: ", DescriptionLibV2.toString(ilk));
    }

    function done() external view override returns (bool) {
        return osm.stopped() == 1;
    }

    function _emergencyActions() internal override {
        address registered = osmMom.osms(ilk);
        if (registered != address(osm)) revert OsmMismatch(address(osm), registered);

        osmMom.stop(ilk);
        emit Stop(address(osm));
    }
}
