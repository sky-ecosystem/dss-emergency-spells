// SPDX-FileCopyrightText: © 2026 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {Test} from "forge-std/Test.sol";

import {SplitterStopSpellV2DeployScript} from "./DeploySplitterStopV2.s.sol";
import {SplitterStopSpellV2} from "../../src/splitter-stop/SplitterStopSpellV2.sol";

contract DeploySplitterStopV2Test is Test {
    address internal constant CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;

    function setUp() public {
        _mockChainlog("MCD_PAUSE", address(1));
    }

    function testChainlogEntrypointUsesKnownContracts() public {
        address mom = address(0x71);
        address splitter = address(0x72);
        _mockChainlog("SPLITTER_MOM", mom);
        _mockChainlog("MCD_SPLIT", splitter);
        vm.mockCall(mom, abi.encodeWithSignature("splitter()"), abi.encode(splitter));

        SplitterStopSpellV2 spell = SplitterStopSpellV2(new SplitterStopSpellV2DeployScript().run());
        assertEq(spell.splitterMom(), mom);
        assertEq(spell.splitter(), splitter);
    }

    function _mockChainlog(bytes32 key, address value) internal {
        vm.mockCall(CHAINLOG, abi.encodeWithSignature("getAddress(bytes32)", key), abi.encode(value));
    }
}
