// SPDX-FileCopyrightText: © 2026 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {EmergencySpellV2} from "../EmergencySpellV2.sol";

enum StUsdsParamV2 {
    CAP,
    LINE,
    BOTH
}

interface StUsdsWipeMomLikeV2 {
    function zeroCap(address rateSetter) external;
    function zeroLine(address rateSetter) external;
}

interface StUsdsWipeRateSetterLikeV2 {
    function maxCap() external view returns (uint256);
    function maxLine() external view returns (uint256);
}

interface StUsdsLikeV2 {
    function cap() external view returns (uint256);
    function ilk() external view returns (bytes32);
    function line() external view returns (uint256);
}

interface StUsdsVatLikeV2 {
    function ilks(bytes32 ilk)
        external
        view
        returns (uint256 Art, uint256 rate, uint256 spot, uint256 line, uint256 dust);
}

contract StUsdsWipeParamSpellV2 is EmergencySpellV2 {
    StUsdsWipeMomLikeV2 public immutable stUsdsMom;
    StUsdsWipeRateSetterLikeV2 public immutable rateSetter;
    StUsdsLikeV2 public immutable stUsds;
    StUsdsVatLikeV2 public immutable vat;
    StUsdsParamV2 public immutable param;
    bytes32 public immutable ilk;

    event ZeroCap();
    event ZeroLine();

    constructor(address stUsdsMom_, address rateSetter_, address stUsds_, StUsdsParamV2 param_) {
        stUsdsMom = StUsdsWipeMomLikeV2(_requireContract(stUsdsMom_));
        rateSetter = StUsdsWipeRateSetterLikeV2(_requireContract(rateSetter_));
        stUsds = StUsdsLikeV2(_requireContract(stUsds_));
        vat = StUsdsVatLikeV2(_requireContract(_log.getAddress("MCD_VAT")));
        param = param_;
        ilk = stUsds.ilk();
    }

    function description() external view override returns (string memory) {
        return string.concat("Emergency Spell | stUSDS | wipe param: ", _paramToString(param));
    }

    function done() external view override returns (bool) {
        bool capDone = stUsds.cap() == 0 && rateSetter.maxCap() == 0;
        if (param == StUsdsParamV2.CAP) return capDone;

        (,,, uint256 vatLine,) = vat.ilks(ilk);
        bool lineDone = vatLine == 0 && stUsds.line() == 0 && rateSetter.maxLine() == 0;
        if (param == StUsdsParamV2.LINE) return lineDone;
        return capDone && lineDone;
    }

    function _emergencyActions() internal override {
        if (param == StUsdsParamV2.LINE || param == StUsdsParamV2.BOTH) {
            stUsdsMom.zeroLine(address(rateSetter));
            emit ZeroLine();
        }
        if (param == StUsdsParamV2.CAP || param == StUsdsParamV2.BOTH) {
            stUsdsMom.zeroCap(address(rateSetter));
            emit ZeroCap();
        }
    }

    function _paramToString(StUsdsParamV2 param_) internal pure returns (string memory) {
        if (param_ == StUsdsParamV2.CAP) return "CAP";
        if (param_ == StUsdsParamV2.LINE) return "LINE";
        return "BOTH";
    }
}
