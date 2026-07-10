// SPDX-FileCopyrightText: © 2026 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {EmergencySpellV2} from "../EmergencySpellV2.sol";

interface SPBEAMMomLikeV2 {
    function halt(address spbeam) external;
}

interface SPBEAMLikeV2 {
    function bad() external view returns (uint256);
}

contract SPBEAMHaltSpellV2 is EmergencySpellV2 {
    string public constant override description = "Emergency Spell | Halt SPBEAM";

    SPBEAMMomLikeV2 public immutable spbeamMom;
    SPBEAMLikeV2 public immutable spbeam;

    event Halt();

    constructor(address spbeamMom_, address spbeam_) {
        spbeamMom = SPBEAMMomLikeV2(_requireContract(spbeamMom_));
        spbeam = SPBEAMLikeV2(_requireContract(spbeam_));
    }

    function done() external view override returns (bool) {
        return spbeam.bad() == 1;
    }

    function _emergencyActions() internal override {
        spbeamMom.halt(address(spbeam));
        emit Halt();
    }
}
