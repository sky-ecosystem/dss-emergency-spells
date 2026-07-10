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
import {ClipBreakerSpellV2} from "../../src/clip-breaker/ClipBreakerSpellV2.sol";
import {GlobalClipBreakerSpellV2} from "../../src/clip-breaker/GlobalClipBreakerSpellV2.sol";

contract ClipBreakerSpellV2DeployScript is Script {
    ChainlogLike internal constant chainlog = ChainlogLike(0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F);

    function run(address clipperMom, address clip, bytes32 ilk) public returns (address deployed) {
        vm.broadcast();
        deployed = address(new ClipBreakerSpellV2(clipperMom, clip, ilk));
    }

    function run(address clip, bytes32 ilk) external returns (address deployed) {
        deployed = run(chainlog.getAddress("CLIPPER_MOM"), clip, ilk);
    }
}

contract GlobalClipBreakerSpellV2DeployScript is Script {
    ChainlogLike internal constant chainlog = ChainlogLike(0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F);

    function run(address ilkRegistry, address clipperMom) public returns (address deployed) {
        vm.broadcast();
        deployed = address(new GlobalClipBreakerSpellV2(ilkRegistry, clipperMom));
    }

    function run() external returns (address deployed) {
        deployed = run(chainlog.getAddress("ILK_REGISTRY"), chainlog.getAddress("CLIPPER_MOM"));
    }
}
