// SPDX-FileCopyrightText: © 2026 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {EmergencySpellV2} from "../EmergencySpellV2.sol";

interface SplitterMomLike {
    function splitter() external view returns (address);
    function stop() external;
}

interface SplitterLike {
    function hop() external view returns (uint256);
}

contract SplitterStopSpellV2 is EmergencySpellV2 {
    string public constant override description = "Emergency Spell | Stop Splitter";

    address public immutable splitterMom;
    address public immutable splitter;

    event Stop();

    constructor(address splitterMom_, address splitter_) {
        splitterMom = splitterMom_;
        splitter = splitter_;
        address configured = SplitterMomLike(splitterMom_).splitter();
        require(configured == splitter_, "SplitterStopSpellV2/splitter-mismatch");
    }

    function done() external view override returns (bool) {
        return SplitterLike(splitter).hop() == type(uint256).max;
    }

    function _emergencyActions() internal override {
        SplitterMomLike(splitterMom).stop();
        emit Stop();
    }
}
