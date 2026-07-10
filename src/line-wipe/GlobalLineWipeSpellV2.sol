// SPDX-FileCopyrightText: © 2026 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {EmergencySpellV2} from "../EmergencySpellV2.sol";

interface IlkRegistryLike {
    function count() external view returns (uint256);
    function list() external view returns (bytes32[] memory);
    function list(uint256 start, uint256 end) external view returns (bytes32[] memory);
}

interface LineMomLike {
    function autoLine() external view returns (address);
    function ilks(bytes32 ilk) external view returns (uint256);
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

/// @notice Wipes every LineMom-enrolled ilk in the live IlkRegistry set.
contract GlobalLineWipeSpellV2 is EmergencySpellV2 {
    string public constant override description = "Emergency Spell | Global Line Wipe";

    address public immutable ilkRegistry;
    address public immutable lineMom;
    address public immutable autoLine;
    address public immutable vat;

    event Wipe(bytes32 indexed ilk);

    constructor(address ilkRegistry_, address lineMom_) {
        ilkRegistry = ilkRegistry_;
        lineMom = lineMom_;
        autoLine = LineMomLike(lineMom_).autoLine();
        vat = _log.getAddress("MCD_VAT");
    }

    function scheduleRange(uint256 start, uint256 end) external {
        uint256 count = IlkRegistryLike(ilkRegistry).count();
        require(count != 0, "GlobalLineWipeSpellV2/empty-registry");
        require(start < count, "GlobalLineWipeSpellV2/start-out-of-bounds");
        require(start <= end, "GlobalLineWipeSpellV2/invalid-range");
        if (end >= count) end = count - 1;
        _wipe(IlkRegistryLike(ilkRegistry).list(start, end));
    }

    function done() external view override returns (bool) {
        bytes32[] memory ilks = IlkRegistryLike(ilkRegistry).list();
        for (uint256 i; i < ilks.length; ++i) {
            bytes32 ilk = ilks[i];
            if (LineMomLike(lineMom).ilks(ilk) == 0) continue;

            (,,, uint256 line,) = VatLike(vat).ilks(ilk);
            (uint256 maxLine, uint256 gap, uint48 ttl, uint48 last, uint48 lastInc) = AutoLineLike(autoLine).ilks(ilk);
            if (line != 0 || maxLine != 0 || gap != 0 || ttl != 0 || last != 0 || lastInc != 0) return false;
        }
        return true;
    }

    function _emergencyActions() internal override {
        _wipe(IlkRegistryLike(ilkRegistry).list());
    }

    function _wipe(bytes32[] memory ilks) internal {
        for (uint256 i; i < ilks.length; ++i) {
            bytes32 ilk = ilks[i];
            if (LineMomLike(lineMom).ilks(ilk) == 0) continue;

            LineMomLike(lineMom).wipe(ilk);
            emit Wipe(ilk);
        }
    }
}
