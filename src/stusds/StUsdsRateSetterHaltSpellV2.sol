// SPDX-FileCopyrightText: © 2026 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {EmergencySpellV2} from "../EmergencySpellV2.sol";

interface StUsdsMomLike {
    function haltRateSetter(address rateSetter) external;
    function stusds() external view returns (address);
}

interface StUsdsRateSetterLike {
    function bad() external view returns (uint8);
    function stusds() external view returns (address);
}

contract StUsdsRateSetterHaltSpellV2 is EmergencySpellV2 {
    string public constant override description = "Emergency Spell | stUSDS | Halt Rate Setter";

    address public immutable stUsdsMom;
    address public immutable rateSetter;
    address public immutable stUsds;

    event HaltRateSetter(address indexed rateSetter);

    constructor(address stUsdsMom_, address rateSetter_) {
        stUsdsMom = stUsdsMom_;
        rateSetter = rateSetter_;
        address expected = StUsdsMomLike(stUsdsMom_).stusds();
        address actual = StUsdsRateSetterLike(rateSetter_).stusds();
        require(actual == expected, "StUsdsRateSetterHaltSpellV2/stusds-mismatch");
        stUsds = expected;
    }

    function done() external view override returns (bool) {
        return StUsdsRateSetterLike(rateSetter).bad() == 1;
    }

    function _emergencyActions() internal override {
        StUsdsMomLike(stUsdsMom).haltRateSetter(rateSetter);
        emit HaltRateSetter(rateSetter);
    }
}
