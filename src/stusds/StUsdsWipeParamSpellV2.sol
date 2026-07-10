// SPDX-FileCopyrightText: © 2026 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {EmergencySpellV2} from "../EmergencySpellV2.sol";

enum Param {
    CAP,
    LINE,
    BOTH
}

interface StUsdsMomLike {
    function stusds() external view returns (address);
    function zeroCap(address rateSetter) external;
    function zeroLine(address rateSetter) external;
}

interface StUsdsRateSetterLike {
    function maxCap() external view returns (uint256);
    function maxLine() external view returns (uint256);
    function stusds() external view returns (address);
}

interface StUsdsLike {
    function cap() external view returns (uint256);
    function ilk() external view returns (bytes32);
    function line() external view returns (uint256);
}

interface VatLike {
    function ilks(bytes32 ilk)
        external
        view
        returns (uint256 Art, uint256 rate, uint256 spot, uint256 line, uint256 dust);
}

contract StUsdsWipeParamSpellV2 is EmergencySpellV2 {
    address public immutable stUsdsMom;
    address public immutable rateSetter;
    address public immutable stUsds;
    address public immutable vat;
    Param public immutable param;
    bytes32 public immutable ilk;

    event ZeroCap();
    event ZeroLine();

    constructor(address stUsdsMom_, address rateSetter_, address stUsds_, Param param_) {
        stUsdsMom = stUsdsMom_;
        rateSetter = rateSetter_;
        stUsds = stUsds_;
        vat = _log.getAddress("MCD_VAT");
        address momSubject = StUsdsMomLike(stUsdsMom_).stusds();
        require(momSubject == stUsds_, "StUsdsWipeParamSpellV2/stusds-mismatch");
        address rateSetterSubject = StUsdsRateSetterLike(rateSetter_).stusds();
        require(rateSetterSubject == stUsds_, "StUsdsWipeParamSpellV2/stusds-mismatch");
        param = param_;
        ilk = StUsdsLike(stUsds_).ilk();
    }

    function description() external view override returns (string memory) {
        return string.concat("Emergency Spell | stUSDS | wipe param: ", _paramToString(param));
    }

    function done() external view override returns (bool) {
        bool capDone = StUsdsLike(stUsds).cap() == 0 && StUsdsRateSetterLike(rateSetter).maxCap() == 0;
        if (param == Param.CAP) return capDone;

        (,,, uint256 vatLine,) = VatLike(vat).ilks(ilk);
        bool lineDone =
            vatLine == 0 && StUsdsLike(stUsds).line() == 0 && StUsdsRateSetterLike(rateSetter).maxLine() == 0;
        if (param == Param.LINE) return lineDone;
        return capDone && lineDone;
    }

    function _emergencyActions() internal override {
        if (param == Param.LINE || param == Param.BOTH) {
            StUsdsMomLike(stUsdsMom).zeroLine(rateSetter);
            emit ZeroLine();
        }
        if (param == Param.CAP || param == Param.BOTH) {
            StUsdsMomLike(stUsdsMom).zeroCap(rateSetter);
            emit ZeroCap();
        }
    }

    function _paramToString(Param param_) internal pure returns (string memory) {
        if (param_ == Param.CAP) return "CAP";
        if (param_ == Param.LINE) return "LINE";
        return "BOTH";
    }
}
