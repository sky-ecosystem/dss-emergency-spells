// SPDX-FileCopyrightText: © 2026 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {EmergencySpellV2} from "../EmergencySpellV2.sol";
import {DescriptionLibV2} from "../libraries/DescriptionLibV2.sol";

enum FlowV2 {
    SELL,
    BUY,
    BOTH
}

interface LitePsmMomLikeV2 {
    function halt(address psm, FlowV2 flow) external;
}

interface LitePsmLikeV2 {
    function tin() external view returns (uint256);
    function tout() external view returns (uint256);
    function HALTED() external view returns (uint256);
    function ilk() external view returns (bytes32);
}

/// @notice Halts a fixed flow direction on one explicitly selected Lite PSM.
contract SingleLitePsmHaltSpellV2 is EmergencySpellV2 {
    LitePsmMomLikeV2 public immutable litePsmMom;
    LitePsmLikeV2 public immutable psm;
    FlowV2 public immutable flow;
    bytes32 public immutable ilk;

    event Halt(FlowV2 flow);

    constructor(address litePsmMom_, address psm_, FlowV2 flow_) {
        litePsmMom = LitePsmMomLikeV2(_requireContract(litePsmMom_));
        psm = LitePsmLikeV2(_requireContract(psm_));
        flow = flow_;
        ilk = psm.ilk();
    }

    function description() external view override returns (string memory) {
        return string.concat("Emergency Spell | ", DescriptionLibV2.toString(ilk), " | halt: ", _flowToString(flow));
    }

    function done() external view override returns (bool) {
        uint256 halted = psm.HALTED();
        if (flow == FlowV2.SELL) return psm.tin() == halted;
        if (flow == FlowV2.BUY) return psm.tout() == halted;
        return psm.tin() == halted && psm.tout() == halted;
    }

    function _emergencyActions() internal override {
        litePsmMom.halt(address(psm), flow);
        emit Halt(flow);
    }

    function _flowToString(FlowV2 flow_) internal pure returns (string memory) {
        if (flow_ == FlowV2.SELL) return "SELL";
        if (flow_ == FlowV2.BUY) return "BUY";
        return "BOTH";
    }
}
