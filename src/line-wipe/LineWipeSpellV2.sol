// SPDX-FileCopyrightText: © 2026 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {EmergencySpellV2} from "../EmergencySpellV2.sol";
import {DescriptionLibV2} from "../libraries/DescriptionLibV2.sol";

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
        return string.concat("Emergency Spell | Line Wipe: ", DescriptionLibV2.toString(ilk));
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
