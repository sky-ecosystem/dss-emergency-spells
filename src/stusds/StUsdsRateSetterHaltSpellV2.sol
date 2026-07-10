// SPDX-FileCopyrightText: © 2026 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {EmergencySpellV2} from "../EmergencySpellV2.sol";

interface StUsdsHaltMomLikeV2 {
    function haltRateSetter(address rateSetter) external;
}

interface StUsdsHaltRateSetterLikeV2 {
    function bad() external view returns (uint8);
}

contract StUsdsRateSetterHaltSpellV2 is EmergencySpellV2 {
    string public constant override description = "Emergency Spell | stUSDS | Halt Rate Setter";

    StUsdsHaltMomLikeV2 public immutable stUsdsMom;
    StUsdsHaltRateSetterLikeV2 public immutable rateSetter;

    event HaltRateSetter(address indexed rateSetter);

    constructor(address stUsdsMom_, address rateSetter_) {
        stUsdsMom = StUsdsHaltMomLikeV2(_requireContract(stUsdsMom_));
        rateSetter = StUsdsHaltRateSetterLikeV2(_requireContract(rateSetter_));
    }

    function done() external view override returns (bool) {
        return rateSetter.bad() == 1;
    }

    function _emergencyActions() internal override {
        stUsdsMom.haltRateSetter(address(rateSetter));
        emit HaltRateSetter(address(rateSetter));
    }
}
