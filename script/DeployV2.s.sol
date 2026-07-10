// SPDX-FileCopyrightText: © 2026 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {Script} from "forge-std/Script.sol";

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

contract LineWipeSpellV2DeployScript is Script {
    function run(address lineMom, bytes32 ilk) external returns (address deployed) {
        vm.broadcast();
        deployed = address(new LineWipeSpellV2(lineMom, ilk));
    }
}

contract ClipBreakerSpellV2DeployScript is Script {
    function run(address clipperMom, address clip, bytes32 ilk) external returns (address deployed) {
        vm.broadcast();
        deployed = address(new ClipBreakerSpellV2(clipperMom, clip, ilk));
    }
}

contract OsmStopSpellV2DeployScript is Script {
    function run(address osmMom, address osm, bytes32 ilk) external returns (address deployed) {
        require(OsmMomLike(osmMom).osms(ilk) == osm, "OsmStopSpellV2DeployScript/osm-mismatch");
        vm.broadcast();
        deployed = address(new OsmStopSpellV2(osmMom, osm, ilk));
    }
}

contract DdmDisableSpellV2DeployScript is Script {
    function run(address ddmMom, address plan, bytes32 ilk) external returns (address deployed) {
        vm.broadcast();
        deployed = address(new DdmDisableSpellV2(ddmMom, plan, ilk));
    }
}

contract LitePsmHaltSpellV2DeployScript is Script {
    function run(address litePsmMom, address psm, Flow flow) external returns (address deployed) {
        vm.broadcast();
        deployed = address(new LitePsmHaltSpellV2(litePsmMom, psm, flow));
    }
}

contract SPBEAMHaltSpellV2DeployScript is Script {
    function run(address spbeamMom, address spbeam) external returns (address deployed) {
        vm.broadcast();
        deployed = address(new SPBEAMHaltSpellV2(spbeamMom, spbeam));
    }
}

contract SplitterStopSpellV2DeployScript is Script {
    function run(address splitterMom, address splitter) external returns (address deployed) {
        vm.broadcast();
        deployed = address(new SplitterStopSpellV2(splitterMom, splitter));
    }
}

contract StUsdsRateSetterDissBudSpellV2DeployScript is Script {
    function run(address stUsdsMom, address rateSetter, address bud) external returns (address deployed) {
        vm.broadcast();
        deployed = address(new StUsdsRateSetterDissBudSpellV2(stUsdsMom, rateSetter, bud));
    }
}

contract StUsdsRateSetterHaltSpellV2DeployScript is Script {
    function run(address stUsdsMom, address rateSetter) external returns (address deployed) {
        vm.broadcast();
        deployed = address(new StUsdsRateSetterHaltSpellV2(stUsdsMom, rateSetter));
    }
}

contract StUsdsWipeParamSpellV2DeployScript is Script {
    function run(address stUsdsMom, address rateSetter, address stUsds, Param param)
        external
        returns (address deployed)
    {
        vm.broadcast();
        deployed = address(new StUsdsWipeParamSpellV2(stUsdsMom, rateSetter, stUsds, param));
    }
}

contract GlobalLineWipeSpellV2DeployScript is Script {
    function run(address ilkRegistry, address lineMom) external returns (address deployed) {
        vm.broadcast();
        deployed = address(new GlobalLineWipeSpellV2(ilkRegistry, lineMom));
    }
}

contract GlobalClipBreakerSpellV2DeployScript is Script {
    function run(address ilkRegistry, address clipperMom) external returns (address deployed) {
        vm.broadcast();
        deployed = address(new GlobalClipBreakerSpellV2(ilkRegistry, clipperMom));
    }
}

contract GlobalOsmStopSpellV2DeployScript is Script {
    function run(address ilkRegistry, address osmMom) external returns (address deployed) {
        vm.broadcast();
        deployed = address(new GlobalOsmStopSpellV2(ilkRegistry, osmMom));
    }
}

contract EmergencySpellBatchFactoryV2DeployScript is Script {
    function run() external returns (address deployed) {
        vm.broadcast();
        deployed = address(new EmergencySpellBatchFactoryV2());
    }
}

contract EmergencySpellBatchV2DeployScript is Script {
    function run(address factory, address[] calldata leaves, string calldata label, bytes32 expectedConfigHash)
        external
        returns (address deployed)
    {
        require(
            keccak256(abi.encode(leaves, label)) == expectedConfigHash,
            "EmergencySpellBatchV2DeployScript/config-hash-mismatch"
        );
        vm.broadcast();
        deployed = EmergencySpellBatchFactoryV2(factory).deploy(leaves, label);
    }

    function runDeterministic(
        address factory,
        address[] calldata leaves,
        string calldata label,
        bytes32 expectedConfigHash
    ) external returns (address deployed) {
        require(
            keccak256(abi.encode(leaves, label)) == expectedConfigHash,
            "EmergencySpellBatchV2DeployScript/config-hash-mismatch"
        );
        vm.broadcast();
        deployed = EmergencySpellBatchFactoryV2(factory).deployDeterministic(leaves, label);
    }

    function preview(address factory, address[] calldata leaves, string calldata label)
        external
        view
        returns (address)
    {
        return EmergencySpellBatchFactoryV2(factory).previewDeterministicAddress(leaves, label);
    }
}
