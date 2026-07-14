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
    }
}
