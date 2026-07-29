// SPDX-FileCopyrightText: © 2026 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {Test} from "forge-std/Test.sol";

import {SPBEAMHaltSpellV2DeployScript} from "./DeploySPBEAMHaltV2.s.sol";
import {SPBEAMHaltSpellV2} from "../../src/spbeam-halt/SPBEAMHaltSpellV2.sol";

contract DeploySPBEAMHaltV2Test is Test {
    address internal constant CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;

    function setUp() public {
        _mockChainlog("MCD_PAUSE", address(1));
    }

    function testChainlogEntrypointUsesKnownContracts() public {
        address mom = address(0x61);
        address spbeam = address(0x62);
        _mockChainlog("SPBEAM_MOM", mom);
        _mockChainlog("MCD_SPBEAM", spbeam);

        SPBEAMHaltSpellV2 spell = SPBEAMHaltSpellV2(new SPBEAMHaltSpellV2DeployScript().run());
        assertEq(spell.spbeamMom(), mom);
        assertEq(spell.spbeam(), spbeam);
    }

    function _mockChainlog(bytes32 key, address value) internal {
        vm.mockCall(CHAINLOG, abi.encodeWithSignature("getAddress(bytes32)", key), abi.encode(value));
    }
}
