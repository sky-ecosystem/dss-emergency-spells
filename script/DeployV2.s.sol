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

import {ChainlogLike} from "../src/EmergencySpellV2.sol";
import {EmergencySpellBatchFactoryV2} from "../src/EmergencySpellBatchFactoryV2.sol";
import {ClipBreakerSpellV2} from "../src/clip-breaker/ClipBreakerSpellV2.sol";
import {GlobalClipBreakerSpellV2} from "../src/clip-breaker/GlobalClipBreakerSpellV2.sol";
import {DdmDisableSpellV2} from "../src/ddm-disable/DdmDisableSpellV2.sol";
import {GlobalLineWipeSpellV2} from "../src/line-wipe/GlobalLineWipeSpellV2.sol";
import {LineWipeSpellV2} from "../src/line-wipe/LineWipeSpellV2.sol";
import {Flow, LitePsmHaltSpellV2} from "../src/lite-psm-halt/LitePsmHaltSpellV2.sol";
import {GlobalOsmStopSpellV2} from "../src/osm-stop/GlobalOsmStopSpellV2.sol";
import {OsmMomLike, OsmStopSpellV2} from "../src/osm-stop/OsmStopSpellV2.sol";
import {SPBEAMHaltSpellV2} from "../src/spbeam-halt/SPBEAMHaltSpellV2.sol";
import {SplitterStopSpellV2} from "../src/splitter-stop/SplitterStopSpellV2.sol";
import {StUsdsRateSetterDissBudSpellV2} from "../src/stusds/StUsdsRateSetterDissBudSpellV2.sol";
import {StUsdsRateSetterHaltSpellV2} from "../src/stusds/StUsdsRateSetterHaltSpellV2.sol";
import {Param, StUsdsWipeParamSpellV2} from "../src/stusds/StUsdsWipeParamSpellV2.sol";

abstract contract ChainlogDeployScript is Script {
    ChainlogLike internal constant chainlog = ChainlogLike(0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F);
}

contract LineWipeSpellV2DeployScript is ChainlogDeployScript {
    function run(address lineMom, bytes32 ilk) public returns (address deployed) {
        vm.broadcast();
        deployed = address(new LineWipeSpellV2(lineMom, ilk));
    }

    function run(bytes32 ilk) external returns (address deployed) {
        deployed = run(chainlog.getAddress("LINE_MOM"), ilk);
    }
}

contract ClipBreakerSpellV2DeployScript is ChainlogDeployScript {
    function run(address clipperMom, address clip, bytes32 ilk) public returns (address deployed) {
        vm.broadcast();
        deployed = address(new ClipBreakerSpellV2(clipperMom, clip, ilk));
    }

    function run(address clip, bytes32 ilk) external returns (address deployed) {
        deployed = run(chainlog.getAddress("CLIPPER_MOM"), clip, ilk);
    }
}

contract OsmStopSpellV2DeployScript is ChainlogDeployScript {
    function run(address osmMom, address osm, bytes32 ilk) public returns (address deployed) {
        require(OsmMomLike(osmMom).osms(ilk) == osm, "OsmStopSpellV2DeployScript/osm-mismatch");
        vm.broadcast();
        deployed = address(new OsmStopSpellV2(osmMom, osm, ilk));
    }

    function run(address osm, bytes32 ilk) external returns (address deployed) {
        deployed = run(chainlog.getAddress("OSM_MOM"), osm, ilk);
    }
}

contract DdmDisableSpellV2DeployScript is ChainlogDeployScript {
    function run(address ddmMom, address plan, bytes32 ilk) public returns (address deployed) {
        vm.broadcast();
        deployed = address(new DdmDisableSpellV2(ddmMom, plan, ilk));
    }

    function run(address plan, bytes32 ilk) external returns (address deployed) {
        deployed = run(chainlog.getAddress("DIRECT_MOM"), plan, ilk);
    }
}

contract LitePsmHaltSpellV2DeployScript is ChainlogDeployScript {
    function run(address litePsmMom, address psm, Flow flow) public returns (address deployed) {
        vm.broadcast();
        deployed = address(new LitePsmHaltSpellV2(litePsmMom, psm, flow));
    }

    function runSell(address psm) external returns (address deployed) {
        deployed = run(chainlog.getAddress("LITE_PSM_MOM"), psm, Flow.SELL);
    }

    function runBuy(address psm) external returns (address deployed) {
        deployed = run(chainlog.getAddress("LITE_PSM_MOM"), psm, Flow.BUY);
    }

    function runBoth(address psm) external returns (address deployed) {
        deployed = run(chainlog.getAddress("LITE_PSM_MOM"), psm, Flow.BOTH);
    }
}

contract SPBEAMHaltSpellV2DeployScript is ChainlogDeployScript {
    function run(address spbeamMom, address spbeam) public returns (address deployed) {
        vm.broadcast();
        deployed = address(new SPBEAMHaltSpellV2(spbeamMom, spbeam));
    }

    function run() external returns (address deployed) {
        deployed = run(chainlog.getAddress("SPBEAM_MOM"), chainlog.getAddress("MCD_SPBEAM"));
    }
}

contract SplitterStopSpellV2DeployScript is ChainlogDeployScript {
    function run(address splitterMom, address splitter) public returns (address deployed) {
        vm.broadcast();
        deployed = address(new SplitterStopSpellV2(splitterMom, splitter));
    }

    function run() external returns (address deployed) {
        deployed = run(chainlog.getAddress("SPLITTER_MOM"), chainlog.getAddress("MCD_SPLIT"));
    }
}

contract StUsdsRateSetterDissBudSpellV2DeployScript is ChainlogDeployScript {
    function run(address stUsdsMom, address rateSetter, address bud) public returns (address deployed) {
        vm.broadcast();
        deployed = address(new StUsdsRateSetterDissBudSpellV2(stUsdsMom, rateSetter, bud));
    }

    function run(address bud) external returns (address deployed) {
        deployed = run(chainlog.getAddress("STUSDS_MOM"), chainlog.getAddress("STUSDS_RATE_SETTER"), bud);
    }
}

contract StUsdsRateSetterHaltSpellV2DeployScript is ChainlogDeployScript {
    function run(address stUsdsMom, address rateSetter) public returns (address deployed) {
        vm.broadcast();
        deployed = address(new StUsdsRateSetterHaltSpellV2(stUsdsMom, rateSetter));
    }

    function run() external returns (address deployed) {
        deployed = run(chainlog.getAddress("STUSDS_MOM"), chainlog.getAddress("STUSDS_RATE_SETTER"));
    }
}

contract StUsdsWipeParamSpellV2DeployScript is ChainlogDeployScript {
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

contract GlobalLineWipeSpellV2DeployScript is ChainlogDeployScript {
    function run(address ilkRegistry, address lineMom) public returns (address deployed) {
        vm.broadcast();
        deployed = address(new GlobalLineWipeSpellV2(ilkRegistry, lineMom));
    }

    function run() external returns (address deployed) {
        deployed = run(chainlog.getAddress("ILK_REGISTRY"), chainlog.getAddress("LINE_MOM"));
    }
}

contract GlobalClipBreakerSpellV2DeployScript is ChainlogDeployScript {
    function run(address ilkRegistry, address clipperMom) public returns (address deployed) {
        vm.broadcast();
        deployed = address(new GlobalClipBreakerSpellV2(ilkRegistry, clipperMom));
    }

    function run() external returns (address deployed) {
        deployed = run(chainlog.getAddress("ILK_REGISTRY"), chainlog.getAddress("CLIPPER_MOM"));
    }
}

contract GlobalOsmStopSpellV2DeployScript is ChainlogDeployScript {
    function run(address ilkRegistry, address osmMom) public returns (address deployed) {
        vm.broadcast();
        deployed = address(new GlobalOsmStopSpellV2(ilkRegistry, osmMom));
    }

    function run() external returns (address deployed) {
        deployed = run(chainlog.getAddress("ILK_REGISTRY"), chainlog.getAddress("OSM_MOM"));
    }
}

contract EmergencySpellBatchFactoryV2DeployScript is Script {
    function run() external returns (address deployed) {
        vm.broadcast();
        deployed = address(new EmergencySpellBatchFactoryV2());
    }
}

contract EmergencySpellBatchV2DeployScript is ChainlogDeployScript {
    function run(address factory, address[] calldata leaves, string calldata label, bytes32 expectedConfigHash)
        public
        returns (address deployed)
    {
        require(
            keccak256(abi.encode(leaves, label)) == expectedConfigHash,
            "EmergencySpellBatchV2DeployScript/config-hash-mismatch"
        );
        vm.broadcast();
        deployed = EmergencySpellBatchFactoryV2(factory).deploy(leaves, label);
    }

    function run(address[] calldata leaves, string calldata label, bytes32 expectedConfigHash)
        external
        returns (address deployed)
    {
        deployed = run(chainlog.getAddress("EMERGENCY_SPELL_BATCH_FAB"), leaves, label, expectedConfigHash);
    }

    function runDeterministic(
        address factory,
        address[] calldata leaves,
        string calldata label,
        bytes32 expectedConfigHash
    ) public returns (address deployed) {
        require(
            keccak256(abi.encode(leaves, label)) == expectedConfigHash,
            "EmergencySpellBatchV2DeployScript/config-hash-mismatch"
        );
        vm.broadcast();
        deployed = EmergencySpellBatchFactoryV2(factory).deployDeterministic(leaves, label);
    }

    function runDeterministic(address[] calldata leaves, string calldata label, bytes32 expectedConfigHash)
        external
        returns (address deployed)
    {
        deployed = runDeterministic(chainlog.getAddress("EMERGENCY_SPELL_BATCH_FAB"), leaves, label, expectedConfigHash);
    }

    function preview(address factory, address[] calldata leaves, string calldata label) public view returns (address) {
        return EmergencySpellBatchFactoryV2(factory).previewDeterministicAddress(leaves, label);
    }

    function preview(address[] calldata leaves, string calldata label) external view returns (address) {
        return preview(chainlog.getAddress("EMERGENCY_SPELL_BATCH_FAB"), leaves, label);
    }
}
