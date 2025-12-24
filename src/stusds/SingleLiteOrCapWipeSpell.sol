// SPDX-FileCopyrightText: © 2024 Dai Foundation <www.daifoundation.org>
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

enum Flow {
    CAP, // Zeros only the cap
    LINE, // Zeros only the line
    BOTH // Zeros both
}

interface StUsdsMomLike {
    function zeroCap(address rateSetter) external;
    function zeroLine(address rateSetter) external;
}

interface StUsdsRateSetterLike {
    function maxCap() external view returns (uint256);
    function maxLine() external view returns (uint256);
    function wards(address) external view returns (uint256);
}

interface StUsdsLike {
    function cap() external view returns (uint256);
    function line() external view returns (uint256);
    function wards(address) external view returns (uint256);
}

/// @title stUSDS Zero Line and Cap Emergency Spell
/// @notice Will zero: cap and line on STUSDS; maxCap and maxLine on STUSDS_RATE_SETTER can zero only cap, only line, or both.
/// @custom:authors [Riccardo]
/// @custom:reviewers []
/// @custom:auditors []
/// @custom:bounties []
contract SingleLiteOrCapWipeSpell is DssEmergencySpell {
    StUsdsMomLike public immutable stUsdsMom;
    StUsdsLike public immutable stUsds;
    StUsdsRateSetterLike public immutable stUsdsRateSetter;
    Flow public immutable flow;

    event ZeroCapOrLine(Flow what);

    constructor(address _stUsdsRateSetter, address _stUsdsMom, address _stUsds, Flow _flow) {
        stUsdsRateSetter = StUsdsRateSetterLike(_stUsdsRateSetter);
        stUsds = StUsdsLike(_stUsds);
        stUsdsMom = StUsdsMomLike(_stUsdsMom);
        flow = _flow;
    }

    function _flowToString(Flow _flow) internal pure returns (string memory) {
        if (_flow == Flow.CAP) return "CAP";
        if (_flow == Flow.LINE) return "LINE";
        if (_flow == Flow.BOTH) return "BOTH";
        return "";
    }

    function description() external view returns (string memory) {
        return string(abi.encodePacked("Emergency Spell | stUSDS | halt: ", _flowToString(flow)));
    }

    /**
     * @notice zero cap; or zero line; or both; on stUSDS and stUSDSRateSetter.
     */
    function _emergencyActions() internal override {
        if (flow == Flow.LINE || flow == Flow.BOTH) {
            stUsdsMom.zeroLine(address(stUsdsRateSetter));
        } 
        if (flow == Flow.CAP || flow == Flow.BOTH) {
            stUsdsMom.zeroCap(address(stUsdsRateSetter));
        } 
        emit ZeroCapOrLine(flow);
    }

    /**
     * @notice Returns whether the spell is done or not.
     * @dev Checks if the line or cap have been zeroed on the stUSDS.
     *      The spell would revert if any of the following conditions holds:
     *          1. stUsdsMom is not a ward of stUsds
     *          2. stUsdsRateSetter is not a ward of stUsds
     *      In both cases, it returns `true`, meaning no further action can be taken at the moment.
     */
    function done() external view returns (bool) {
        try stUsds.wards(address(stUsdsMom)) returns (uint256 ward) {
            // Ignore StUsds instances that have not relied on StUsdsMom.
            if (ward == 0) {
                return true;
            }
        } catch {
            // If the call failed, it means the contract is most likely not a StUsds instance.
            return true;
        }

        try stUsds.wards(address(stUsdsRateSetter)) returns (uint256 ward) {
            // Ignore StUsds instances that have not relied on StUsdsMom.
            if (ward == 0) {
                return true;
            }
        } catch {
            // If the call failed, it means the contract is most likely not a StUsds instance.
            return true;
        }

        try stUsdsRateSetter.wards(address(stUsdsMom)) returns (uint256 ward) {
            // Ignore StUsdsRateSetter instances that have not relied on StUsdsMom.
            if (ward == 0) {
                return true;
            }
        } catch {
            // If the call failed, it means the contract is most likely not a RateSetter instance.
            return true;
        }
        
        if (flow == Flow.LINE) {
            return stUsds.line() == 0 && stUsdsRateSetter.maxLine() == 0;
        }
        if (flow == Flow.CAP) {
            return stUsds.cap() == 0 && stUsdsRateSetter.maxCap() == 0;
        }

        return stUsds.cap() == 0 && stUsdsRateSetter.maxCap() == 0 && stUsds.line() == 0 && stUsdsRateSetter.maxLine() == 0;
    }
}

contract SingleLiteOrCapWipeFactory {
    event Deploy(address stUsdsRateSetter, Flow indexed flow, address spell);

    function deploy(address stUsdsRateSetter, address stUsdsMom, address stUsds, Flow flow) external returns (address spell) {
        spell = address(new SingleLiteOrCapWipeSpell(stUsdsRateSetter, stUsdsMom, stUsds, flow));
        emit Deploy(stUsdsRateSetter, flow, spell);
    }
}
