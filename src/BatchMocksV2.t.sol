// SPDX-FileCopyrightText: © 2026 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {EmergencySpellV2} from "./EmergencySpellV2.sol";

contract BatchTargetV2 {
    uint256 public value;
    address public caller;

    event ValueSet(uint256 value, address caller);

    function setValue(uint256 value_) external {
        value = value_;
        caller = msg.sender;
        emit ValueSet(value_, msg.sender);
    }
}

contract BatchLeafV2 is EmergencySpellV2 {
    BatchTargetV2 public immutable target;
    uint256 public immutable value;

    constructor(address target_, uint256 value_) {
        target = BatchTargetV2(target_);
        value = value_;
    }

    function description() external pure override returns (string memory) {
        return "Emergency Spell | Test Leaf";
    }

    function done() external view override returns (bool) {
        return target.value() == value;
    }

    function _emergencyActions() internal override {
        target.setValue(value);
    }
}

contract RevertingBatchLeafV2 is EmergencySpellV2 {
    error LeafFailure(uint256 reason);

    uint256 public immutable reason;

    constructor(uint256 reason_) {
        reason = reason_;
    }

    function description() external pure override returns (string memory) {
        return "Emergency Spell | Reverting Test Leaf";
    }

    function done() external pure override returns (bool) {
        return false;
    }

    function _emergencyActions() internal view override {
        revert LeafFailure(reason);
    }
}
