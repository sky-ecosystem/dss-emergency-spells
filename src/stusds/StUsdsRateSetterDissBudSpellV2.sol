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
    }
}
