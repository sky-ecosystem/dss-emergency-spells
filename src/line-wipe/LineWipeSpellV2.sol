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

interface LineMomLike {
    function autoLine() external view returns (address);
    function wipe(bytes32 ilk) external returns (uint256);
}

interface AutoLineLike {
    function ilks(bytes32 ilk)
        external
        view
        returns (uint256 maxLine, uint256 gap, uint48 ttl, uint48 last, uint48 lastInc);
}

interface VatLike {
    function ilks(bytes32 ilk)
        external
        view
        returns (uint256 Art, uint256 rate, uint256 spot, uint256 line, uint256 dust);
}

/// @notice Wipes one explicitly selected ilk from LineMom, AutoLine, and Vat debt ceilings.
contract LineWipeSpellV2 is EmergencySpellV2 {
    address public immutable lineMom;
    address public immutable autoLine;
    address public immutable vat;
    bytes32 public immutable ilk;

    event Wipe();

    constructor(address lineMom_, bytes32 ilk_) {
        lineMom = lineMom_;
        autoLine = LineMomLike(lineMom_).autoLine();
        vat = _log.getAddress("MCD_VAT");
        ilk = ilk_;
    }

    function description() external view override returns (string memory) {
        return string(abi.encodePacked("Emergency Spell | Line Wipe: ", ilk));
    }

    function done() external view override returns (bool) {
        (,,, uint256 line,) = VatLike(vat).ilks(ilk);
        (uint256 maxLine, uint256 gap, uint48 ttl, uint48 last, uint48 lastInc) = AutoLineLike(autoLine).ilks(ilk);
        return line == 0 && maxLine == 0 && gap == 0 && ttl == 0 && last == 0 && lastInc == 0;
    }

    function _emergencyActions() internal override {
        LineMomLike(lineMom).wipe(ilk);
        emit Wipe();
    }
}
