// SPDX-FileCopyrightText: © 2026 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {EmergencySpellV2} from "../EmergencySpellV2.sol";

interface SplitterMomLikeV2 {
    function stop() external;
}

interface SplitterLikeV2 {
    function hop() external view returns (uint256);
}

contract SplitterStopSpellV2 is EmergencySpellV2 {
    string public constant override description = "Emergency Spell | Stop Splitter";

    SplitterMomLikeV2 public immutable splitterMom;
    SplitterLikeV2 public immutable splitter;

    event Stop();

    constructor(address splitterMom_, address splitter_) {
        splitterMom = SplitterMomLikeV2(_requireContract(splitterMom_));
        splitter = SplitterLikeV2(_requireContract(splitter_));
    }

    function done() external view override returns (bool) {
        return splitter.hop() == type(uint256).max;
    }

    function _emergencyActions() internal override {
        splitterMom.stop();
        emit Stop();
    }
}
