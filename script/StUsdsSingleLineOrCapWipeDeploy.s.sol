// SPDX-FileCopyrightText: © 2023 Dai Foundation <www.daifoundation.org>
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
import {stdJson} from "forge-std/StdJson.sol";
import {ScriptTools} from "dss-test/ScriptTools.sol";
import {StUsdsSingleLineOrCapWipeFactory, Flow} from "src/stusds/StUsdsSingleLineOrCapWipeSpell.sol";

contract StUsdsSingleLineOrCapWipeDeployScript is Script {
    using stdJson for string;
    using ScriptTools for string;

    string constant NAME = "single-stusds-line-or-cap-wipe-deploy";
    string config;

    StUsdsSingleLineOrCapWipeFactory fab;

    function run() external {
        config = ScriptTools.loadConfig();

        fab = StUsdsSingleLineOrCapWipeFactory(config.readAddress(".factory", "FOUNDRY_FACTORY"));

        vm.startBroadcast();

        ScriptTools.exportContract(NAME, "STUSDS_LINE", fab.deploy(Flow.LINE));
        ScriptTools.exportContract(NAME, "STUSDS_BUY", fab.deploy(Flow.CAP));
        ScriptTools.exportContract(NAME, "STUSDS_BOTH", fab.deploy(Flow.BOTH));
    
        vm.stopBroadcast();
    }
}
