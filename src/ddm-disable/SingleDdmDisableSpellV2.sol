// SPDX-FileCopyrightText: © 2026 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {EmergencySpellV2} from "../EmergencySpellV2.sol";
import {DescriptionLibV2} from "../libraries/DescriptionLibV2.sol";

interface DdmMomLikeV2 {
    function disable(address plan) external;
}

interface DdmPlanLikeV2 {
    function active() external view returns (bool);
}

/// @notice Disables one explicitly selected Direct Deposit Module plan.
contract SingleDdmDisableSpellV2 is EmergencySpellV2 {
    DdmMomLikeV2 public immutable ddmMom;
    DdmPlanLikeV2 public immutable plan;
    bytes32 public immutable ilk;

    event Disable(address indexed plan);

    constructor(address ddmMom_, address plan_, bytes32 ilk_) {
        ddmMom = DdmMomLikeV2(_requireContract(ddmMom_));
        plan = DdmPlanLikeV2(_requireContract(plan_));
        ilk = ilk_;
    }

    function description() external view override returns (string memory) {
        return string.concat("Emergency Spell | Disable DDM Plan: ", DescriptionLibV2.toString(ilk));
    }

    function done() external view override returns (bool) {
        return !plan.active();
    }

    function _emergencyActions() internal override {
        ddmMom.disable(address(plan));
        emit Disable(address(plan));
    }
}
