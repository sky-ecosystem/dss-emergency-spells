// SPDX-FileCopyrightText: © 2026 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {EmergencySpellV2} from "../EmergencySpellV2.sol";

interface IlkRegistryLike {
    function count() external view returns (uint256);
    function list() external view returns (bytes32[] memory);
    function list(uint256 start, uint256 end) external view returns (bytes32[] memory);
    function xlip(bytes32 ilk) external view returns (address);
}

interface ClipperMomLike {
    function setBreaker(address clip, uint256 level, uint256 delay) external;
}

interface ClipLike {
    function stopped() external view returns (uint256);
}

/// @notice Sets every nonzero live IlkRegistry Clipper to the fully stopped breaker level.
contract GlobalClipBreakerSpellV2 is EmergencySpellV2 {
    string public constant override description = "Emergency Spell | Global Clip Breaker";
    uint256 public constant BREAKER_LEVEL = 3;
    uint256 public constant BREAKER_DELAY = 0;

    address public immutable ilkRegistry;
    address public immutable clipperMom;

    event SetBreaker(bytes32 indexed ilk, address indexed clip);

    constructor(address ilkRegistry_, address clipperMom_) {
        ilkRegistry = ilkRegistry_;
        clipperMom = clipperMom_;
    }

    function scheduleRange(uint256 start, uint256 end) external {
        uint256 count = IlkRegistryLike(ilkRegistry).count();
        require(count != 0, "GlobalClipBreakerSpellV2/empty-registry");
        require(start < count, "GlobalClipBreakerSpellV2/start-out-of-bounds");
        require(start <= end, "GlobalClipBreakerSpellV2/invalid-range");
        if (end >= count) end = count - 1;
        _setBreakers(IlkRegistryLike(ilkRegistry).list(start, end));
    }

    function done() external view override returns (bool) {
        bytes32[] memory ilks = IlkRegistryLike(ilkRegistry).list();
        for (uint256 i; i < ilks.length; ++i) {
            address clip = IlkRegistryLike(ilkRegistry).xlip(ilks[i]);
            if (clip == address(0)) continue;
            if (ClipLike(clip).stopped() != BREAKER_LEVEL) return false;
        }
        return true;
    }

    function _emergencyActions() internal override {
        _setBreakers(IlkRegistryLike(ilkRegistry).list());
    }

    function _setBreakers(bytes32[] memory ilks) internal {
        for (uint256 i; i < ilks.length; ++i) {
            bytes32 ilk = ilks[i];
            address clip = IlkRegistryLike(ilkRegistry).xlip(ilk);
            if (clip == address(0)) continue;

            ClipperMomLike(clipperMom).setBreaker(clip, BREAKER_LEVEL, BREAKER_DELAY);
            require(ClipLike(clip).stopped() == BREAKER_LEVEL, "GlobalClipBreakerSpellV2/not-stopped");
            emit SetBreaker(ilk, clip);
        }
    }
}
