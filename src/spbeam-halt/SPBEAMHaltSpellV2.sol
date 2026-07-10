// SPDX-FileCopyrightText: © 2026 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
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

    event Halt();

    constructor(address spbeamMom_, address spbeam_) {
        spbeamMom = spbeamMom_;
        spbeam = spbeam_;
    }

    function done() external view override returns (bool) {
        return SPBEAMLike(spbeam).bad() == 1;
    }

    function _emergencyActions() internal override {
        SPBEAMMomLike(spbeamMom).halt(spbeam);
        emit Halt();
    }
}
