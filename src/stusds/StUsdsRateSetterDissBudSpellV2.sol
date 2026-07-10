// SPDX-FileCopyrightText: © 2026 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {EmergencySpellV2} from "../EmergencySpellV2.sol";

interface StUsdsDissMomLikeV2 {
    function dissRateSetterBud(address rateSetter, address bud) external;
}

interface StUsdsDissRateSetterLikeV2 {
    function buds(address bud) external view returns (uint256);
}

contract StUsdsRateSetterDissBudSpellV2 is EmergencySpellV2 {
    string public constant override description = "Emergency Spell | stUSDS | Diss Rate Setter Bud";

    StUsdsDissMomLikeV2 public immutable stUsdsMom;
    StUsdsDissRateSetterLikeV2 public immutable rateSetter;
    address public immutable bud;

    event DissRateSetterBud(address indexed rateSetter, address bud);

    constructor(address stUsdsMom_, address rateSetter_, address bud_) {
        stUsdsMom = StUsdsDissMomLikeV2(_requireContract(stUsdsMom_));
        rateSetter = StUsdsDissRateSetterLikeV2(_requireContract(rateSetter_));
        bud = bud_;
    }

    function done() external view override returns (bool) {
        return rateSetter.buds(bud) == 0;
    }

    function _emergencyActions() internal override {
        stUsdsMom.dissRateSetterBud(address(rateSetter), bud);
        emit DissRateSetterBud(address(rateSetter), bud);
    }
}
