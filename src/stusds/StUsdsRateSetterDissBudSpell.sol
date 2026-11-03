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

import {DssEmergencySpell} from "../DssEmergencySpell.sol";

interface StUsdsMomLike {
    function dissRateSetterBud(address rateSetter, address bud) external;
}

interface StUsdsRateSetterLike {
    function buds(address) external view returns (uint256);
    function wards(address) external view returns (uint256);
}

interface StUsdsLike {
    function wards(address) external view returns (uint256);
}

contract StUsdsRateSetterDissBudSpell is DssEmergencySpell {
    string public constant override description = "Emergency Spell | stUSDS | Diss Rate Setter Bud";

    StUsdsLike public immutable stUsds = StUsdsLike(_log.getAddress("STUSDS"));
    StUsdsMomLike public immutable stUsdsMom = StUsdsMomLike(_log.getAddress("STUSDS_MOM"));
    StUsdsRateSetterLike public immutable stUsdsRateSetter =
        StUsdsRateSetterLike(_log.getAddress("STUSDS_RATE_SETTER"));

    address public immutable bud;

    event DissRateSetterBud(address indexed rateSetter, address bud);

    constructor(address _bud) {
        bud = _bud;
    }

    function _emergencyActions() internal override {
        stUsdsMom.dissRateSetterBud(address(stUsdsRateSetter), bud);
        emit DissRateSetterBud(address(stUsdsRateSetter), bud);
    }

    /**
     * @notice Returns whether the spell is done or not.
     * @dev Checks if the bud has been dissed from the rate setter.
     *      Authorization (`wards`) is not treated as completion: de-authorizing rateSetter/mom
     *      must not mark an incomplete dissBud as done. Calls that revert are still treated as
     *      "not a StUsds / RateSetter instance" (N/A → done).
     *      Note: the spell would revert on cast if any of the following holds:
     *          1. stUsdsRateSetter is not ward on stUsds;
     *          2. stUsdsMom is not ward on stUsdsRateSetter.
     */
    function done() external view returns (bool) {
        // Shape checks only — do not interpret ward==0 as success (false-complete after de-auth).
        try stUsds.wards(address(stUsdsRateSetter)) {
            // Authorization state is irrelevant to completion; outcomes below decide.
        } catch {
            // If the call failed, it means the contract is most likely not a StUsds instance.
            return true;
        }

        try stUsdsRateSetter.wards(address(stUsdsMom)) {
            // Authorization state is irrelevant to completion; outcomes below decide.
        } catch {
            // If the call failed, it means the contract is most likely not a RateSetter instance.
            return true;
        }

        try stUsdsRateSetter.buds(bud) returns (uint256 pBud) {
            return pBud == 0;
        } catch {
            // If the call failed, it means the contract is most likely not a RateSetter instance.
            return true;
        }
    }
}

contract StUsdsRateSetterDissBudFactory {
    event Deploy(address indexed bud, address spell);

    function deploy(address bud) external returns (address spell) {
        spell = address(new StUsdsRateSetterDissBudSpell(bud));
        emit Deploy(bud, spell);
    }
}
