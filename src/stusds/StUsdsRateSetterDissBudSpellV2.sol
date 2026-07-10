// SPDX-FileCopyrightText: © 2026 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {EmergencySpellV2} from "../EmergencySpellV2.sol";

interface StUsdsMomLike {
    function dissRateSetterBud(address rateSetter, address bud) external;
    function stusds() external view returns (address);
}

interface StUsdsRateSetterLike {
    function buds(address bud) external view returns (uint256);
    function stusds() external view returns (address);
}

contract StUsdsRateSetterDissBudSpellV2 is EmergencySpellV2 {
    string public constant override description = "Emergency Spell | stUSDS | Diss Rate Setter Bud";

    address public immutable stUsdsMom;
    address public immutable rateSetter;
    address public immutable stUsds;
    address public immutable bud;

    event DissRateSetterBud(address indexed rateSetter, address bud);

    constructor(address stUsdsMom_, address rateSetter_, address bud_) {
        stUsdsMom = stUsdsMom_;
        rateSetter = rateSetter_;
        address expected = StUsdsMomLike(stUsdsMom_).stusds();
        address actual = StUsdsRateSetterLike(rateSetter_).stusds();
        require(actual == expected, "StUsdsRateSetterDissBudSpellV2/stusds-mismatch");
        stUsds = expected;
        bud = bud_;
    }

    function done() external view override returns (bool) {
        return StUsdsRateSetterLike(rateSetter).buds(bud) == 0;
    }

    function _emergencyActions() internal override {
        StUsdsMomLike(stUsdsMom).dissRateSetterBud(rateSetter, bud);
        emit DissRateSetterBud(rateSetter, bud);
    }
}
