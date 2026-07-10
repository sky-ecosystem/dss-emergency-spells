// SPDX-FileCopyrightText: © 2026 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.
pragma solidity ^0.8.16;

import {Script} from "forge-std/Script.sol";

import {ChainlogLike} from "../../src/EmergencySpellV2.sol";
import {StUsdsRateSetterDissBudSpellV2} from "../../src/stusds/StUsdsRateSetterDissBudSpellV2.sol";
import {StUsdsRateSetterHaltSpellV2} from "../../src/stusds/StUsdsRateSetterHaltSpellV2.sol";
import {Param, StUsdsWipeParamSpellV2} from "../../src/stusds/StUsdsWipeParamSpellV2.sol";

contract StUsdsRateSetterDissBudSpellV2DeployScript is Script {
    ChainlogLike internal constant chainlog = ChainlogLike(0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F);

    function run(address stUsdsMom, address rateSetter, address bud) public returns (address deployed) {
        vm.broadcast();
        deployed = address(new StUsdsRateSetterDissBudSpellV2(stUsdsMom, rateSetter, bud));
    }

    function run(address bud) external returns (address deployed) {
        deployed = run(chainlog.getAddress("STUSDS_MOM"), chainlog.getAddress("STUSDS_RATE_SETTER"), bud);
    }
}

contract StUsdsRateSetterHaltSpellV2DeployScript is Script {
    ChainlogLike internal constant chainlog = ChainlogLike(0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F);

    function run(address stUsdsMom, address rateSetter) public returns (address deployed) {
        vm.broadcast();
        deployed = address(new StUsdsRateSetterHaltSpellV2(stUsdsMom, rateSetter));
    }

    function run() external returns (address deployed) {
        deployed = run(chainlog.getAddress("STUSDS_MOM"), chainlog.getAddress("STUSDS_RATE_SETTER"));
    }
}

contract StUsdsWipeParamSpellV2DeployScript is Script {
    ChainlogLike internal constant chainlog = ChainlogLike(0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F);

    function run(address stUsdsMom, address rateSetter, address stUsds, Param param) public returns (address deployed) {
        vm.broadcast();
        deployed = address(new StUsdsWipeParamSpellV2(stUsdsMom, rateSetter, stUsds, param));
    }

    function runCap() external returns (address deployed) {
        deployed = run(
            chainlog.getAddress("STUSDS_MOM"),
            chainlog.getAddress("STUSDS_RATE_SETTER"),
            chainlog.getAddress("STUSDS"),
            Param.CAP
        );
    }

    function runLine() external returns (address deployed) {
        deployed = run(
            chainlog.getAddress("STUSDS_MOM"),
            chainlog.getAddress("STUSDS_RATE_SETTER"),
            chainlog.getAddress("STUSDS"),
            Param.LINE
        );
    }

    function runBoth() external returns (address deployed) {
        deployed = run(
            chainlog.getAddress("STUSDS_MOM"),
            chainlog.getAddress("STUSDS_RATE_SETTER"),
            chainlog.getAddress("STUSDS"),
            Param.BOTH
        );
    }
}
