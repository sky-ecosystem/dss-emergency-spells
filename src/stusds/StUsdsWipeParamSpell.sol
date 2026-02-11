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

enum Param {
    CAP, // Set to Zero only the cap
    LINE, // Set to Zero only the line
    BOTH // Set to Zero both cap and line
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

/// @title stUSDS Wipe Param Emergency Spell
/// @notice Will set to zero: cap or/and line on STUSDS; maxCap or/and maxLine on STUSDS_RATE_SETTER. Can set to zero only cap, only line, or both.
/// @custom:authors [Riccardo]
/// @custom:reviewers []
/// @custom:auditors []
/// @custom:bounties []
contract StUsdsWipeParamSpell is DssEmergencySpell {
    StUsdsMomLike public immutable stUsdsMom = StUsdsMomLike(_log.getAddress("STUSDS_MOM"));
    StUsdsRateSetterLike public immutable stUsdsRateSetter =
        StUsdsRateSetterLike(_log.getAddress("STUSDS_RATE_SETTER"));
    StUsdsLike public immutable stUsds = StUsdsLike(_log.getAddress("STUSDS"));
    Param public immutable param;

    event ZeroCap();
    event ZeroLine();

    constructor(Param _param) {
        param = _param;
    }

    function _paramToString(Param _param) internal pure returns (string memory) {
        if (_param == Param.CAP) return "CAP";
        if (_param == Param.LINE) return "LINE";
        if (_param == Param.BOTH) return "BOTH";
        return "";
    }

    function description() external view returns (string memory) {
        return string(abi.encodePacked("Emergency Spell | stUSDS | halt: ", _paramToString(param)));
    }

    /**
     * @notice Set to zero the `cap`; or set to zero the `line`; or both; on stUSDS and stUSDSRateSetter.
     */
    function _emergencyActions() internal override {
        if (param == Param.LINE || param == Param.BOTH) {
            stUsdsMom.zeroLine(address(stUsdsRateSetter));
            emit ZeroLine();
        }
        if (param == Param.CAP || param == Param.BOTH) {
            stUsdsMom.zeroCap(address(stUsdsRateSetter));
            emit ZeroCap();
        }
    }

    /**
     * @notice Returns whether the spell is done or not.
     * @dev Checks if the line or cap have been zeroed on the stUSDS.
     *      The spell would revert if any of the following conditions holds:
     *          1. stUsdsMom is not a ward of stUsds;
     *          2. stUsdsRateSetter is not a ward of stUsds;
     *          3. stUsdsMom is not a ward of stUsdsRateSetter.
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

        if (param == Param.LINE) {
            return stUsds.line() == 0 && stUsdsRateSetter.maxLine() == 0;
        }
        if (param == Param.CAP) {
            return stUsds.cap() == 0 && stUsdsRateSetter.maxCap() == 0;
        }

        return
            stUsds.cap() == 0 && stUsdsRateSetter.maxCap() == 0 && stUsds.line() == 0 && stUsdsRateSetter.maxLine() == 0;
    }
}

contract StUsdsWipeParamFactory {
    event Deploy(Param indexed param, address spell);

    function deploy(Param param) external returns (address spell) {
        spell = address(new StUsdsWipeParamSpell(param));
        emit Deploy(param, spell);
    }
}
