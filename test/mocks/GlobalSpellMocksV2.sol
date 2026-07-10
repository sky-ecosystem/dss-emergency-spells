// SPDX-FileCopyrightText: © 2026 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

contract IlkRegistryMockV2 {
    bytes32[] private _ilks;
    mapping(bytes32 => address) public xlip;

    function add(bytes32 ilk) external {
        _ilks.push(ilk);
    }

    function setXlip(bytes32 ilk, address clip) external {
        xlip[ilk] = clip;
    }

    function count() external view returns (uint256) {
        return _ilks.length;
    }

    function list() external view returns (bytes32[] memory) {
        return _ilks;
    }

    function list(uint256 start, uint256 end) external view returns (bytes32[] memory selected) {
        require(start <= end && end < _ilks.length, "IlkRegistryMockV2/invalid-range");
        selected = new bytes32[](end - start + 1);
        for (uint256 i; i < selected.length; ++i) {
            selected[i] = _ilks[start + i];
        }
    }
}

contract VatGlobalMockV2 {
    mapping(bytes32 => uint256) public line;

    function setLine(bytes32 ilk, uint256 line_) external {
        line[ilk] = line_;
    }

    function ilks(bytes32 ilk)
        external
        view
        returns (uint256 Art, uint256 rate, uint256 spot, uint256 line_, uint256 dust)
    {
        return (0, 0, 0, line[ilk], 0);
    }
}

contract AutoLineGlobalMockV2 {
    struct Config {
        uint256 maxLine;
        uint256 gap;
        uint48 ttl;
        uint48 last;
        uint48 lastInc;
    }

    mapping(bytes32 => Config) internal configs;
    mapping(bytes32 => bool) public revertOnRead;

    function set(bytes32 ilk) external {
        configs[ilk] = Config({maxLine: 1, gap: 2, ttl: 3, last: 4, lastInc: 5});
    }

    function clear(bytes32 ilk) external {
        delete configs[ilk];
    }

    function setRevertOnRead(bytes32 ilk, bool value) external {
        revertOnRead[ilk] = value;
    }

    function ilks(bytes32 ilk)
        external
        view
        returns (uint256 maxLine, uint256 gap, uint48 ttl, uint48 last, uint48 lastInc)
    {
        require(!revertOnRead[ilk], "AutoLineGlobalMockV2/read-failed");
        Config memory config = configs[ilk];
        return (config.maxLine, config.gap, config.ttl, config.last, config.lastInc);
    }
}

contract LineMomGlobalMockV2 {
    address public immutable autoLine;
    address public immutable vat;

    mapping(address => bool) public authorized;
    mapping(bytes32 => uint256) internal enrolled;
    mapping(bytes32 => bool) public noopOnWipe;
    mapping(bytes32 => bool) public revertOnWipe;

    constructor(address autoLine_, address vat_) {
        autoLine = autoLine_;
        vat = vat_;
    }

    function rely(address caller) external {
        authorized[caller] = true;
    }

    function enroll(bytes32 ilk) external {
        enrolled[ilk] = 1;
        AutoLineGlobalMockV2(autoLine).set(ilk);
        VatGlobalMockV2(vat).setLine(ilk, 6);
    }

    function setRevertOnWipe(bytes32 ilk, bool value) external {
        revertOnWipe[ilk] = value;
    }

    function setNoopOnWipe(bytes32 ilk, bool value) external {
        noopOnWipe[ilk] = value;
    }

    function ilks(bytes32 ilk) external view returns (uint256) {
        return enrolled[ilk];
    }

    function wipe(bytes32 ilk) external returns (uint256) {
        require(authorized[msg.sender], "LineMomGlobalMockV2/not-authorized");
        require(!revertOnWipe[ilk], "LineMomGlobalMockV2/wipe-failed");
        if (noopOnWipe[ilk]) return 0;
        delete enrolled[ilk];
        AutoLineGlobalMockV2(autoLine).clear(ilk);
        VatGlobalMockV2(vat).setLine(ilk, 0);
        return 0;
    }
}

interface BreakerSettableLike {
    function setStopped(uint256 level) external;
}

contract ClipGlobalMockV2 {
    uint256 public stopped;

    function setStopped(uint256 level) external {
        stopped = level;
    }
}

contract RevertingClipGlobalMockV2 {
    uint256 public stopped;

    function setStopped(uint256) external pure {
        require(false, "RevertingClipGlobalMockV2/set-failed");
    }
}

contract PermissiveClipGlobalMockV2 {
    uint256 public stopped;

    fallback() external {}
}

contract ClipperMomGlobalMockV2 {
    mapping(address => bool) public authorized;

    function rely(address caller) external {
        authorized[caller] = true;
    }

    function setBreaker(address clip, uint256 level, uint256) external {
        require(authorized[msg.sender], "ClipperMomGlobalMockV2/not-authorized");
        BreakerSettableLike(clip).setStopped(level);
    }
}

interface StoppableLike {
    function stop() external;
}

contract OsmGlobalMockV2 {
    uint256 public stopped;

    function stop() external {
        stopped = 1;
    }
}

contract RevertingOsmGlobalMockV2 {
    uint256 public stopped;

    function stop() external pure {
        require(false, "RevertingOsmGlobalMockV2/stop-failed");
    }
}

contract PermissiveOsmGlobalMockV2 {
    uint256 public stopped;

    fallback() external {}
}

contract OsmMomGlobalMockV2 {
    mapping(bytes32 => address) public osms;
    mapping(address => bool) public authorized;

    function rely(address caller) external {
        authorized[caller] = true;
    }

    function setOsm(bytes32 ilk, address osm) external {
        osms[ilk] = osm;
    }

    function stop(bytes32 ilk) external {
        require(authorized[msg.sender], "OsmMomGlobalMockV2/not-authorized");
        StoppableLike(osms[ilk]).stop();
    }
}

contract MalformedGlobalTargetV2 {}
