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

enum Flow {
    SELL,
    BUY,
    BOTH
}

interface LitePsmMomLike {
    function halt(address psm, Flow flow) external;
}

interface LitePsmLike {
    function tin() external view returns (uint256);
    function tout() external view returns (uint256);
    function HALTED() external view returns (uint256);
    function ilk() external view returns (bytes32);
}

/// @notice Halts a fixed flow direction on one explicitly selected Lite PSM.
contract LitePsmHaltSpellV2 is EmergencySpellV2 {
    address public immutable litePsmMom;
    address public immutable psm;
    Flow public immutable flow;
    bytes32 public immutable ilk;

    constructor(address litePsmMom_, address psm_, Flow flow_) {
        litePsmMom = litePsmMom_;
        psm = psm_;
        flow = flow_;
        ilk = LitePsmLike(psm_).ilk();
    }

    function description() external view override returns (string memory) {
        return string(abi.encodePacked("Emergency Spell | ", ilk, " | halt: ", _flowToString(flow)));
    }

    function done() external view override returns (bool) {
        uint256 halted = LitePsmLike(psm).HALTED();
        if (flow == Flow.SELL) return LitePsmLike(psm).tin() == halted;
        if (flow == Flow.BUY) return LitePsmLike(psm).tout() == halted;
        return LitePsmLike(psm).tin() == halted && LitePsmLike(psm).tout() == halted;
    }

    function _emergencyActions() internal override {
        LitePsmMomLike(litePsmMom).halt(psm, flow);
    }

    function _flowToString(Flow flow_) internal pure returns (string memory) {
        if (flow_ == Flow.SELL) return "SELL";
        if (flow_ == Flow.BUY) return "BUY";
        return "BOTH";
    }
}
