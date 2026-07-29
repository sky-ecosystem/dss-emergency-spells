// SPDX-FileCopyrightText: © 2026 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {Test} from "forge-std/Test.sol";

import {ClipBreakerSpellV2DeployScript, GlobalClipBreakerSpellV2DeployScript} from "./DeployClipBreakerV2.s.sol";
import {ClipBreakerSpellV2} from "../../src/clip-breaker/ClipBreakerSpellV2.sol";
import {GlobalClipBreakerSpellV2} from "../../src/clip-breaker/GlobalClipBreakerSpellV2.sol";

contract DeployClipBreakerV2Test is Test {
    address internal constant CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;

    function setUp() public {
        _mockChainlog("MCD_PAUSE", address(1));
    }

    function testExplicitAndChainlogEntrypointsKeepClipExplicit() public {
        address clipperMom = address(0x21);
        address clip = address(0x22);
        address registry = address(0x23);
        bytes32 ilk = "ETH-A";
        _mockChainlog("CLIPPER_MOM", clipperMom);
        _mockChainlog("ILK_REGISTRY", registry);

        ClipBreakerSpellV2 explicitLeaf =
            ClipBreakerSpellV2(new ClipBreakerSpellV2DeployScript().run(clipperMom, clip, ilk));
        ClipBreakerSpellV2 chainlogLeaf = ClipBreakerSpellV2(new ClipBreakerSpellV2DeployScript().run(clip, ilk));
        GlobalClipBreakerSpellV2 global = GlobalClipBreakerSpellV2(new GlobalClipBreakerSpellV2DeployScript().run());

        assertEq(explicitLeaf.clipperMom(), clipperMom);
        assertEq(chainlogLeaf.clipperMom(), clipperMom);
        assertEq(chainlogLeaf.clip(), clip);
        assertEq(chainlogLeaf.ilk(), ilk);
        assertEq(global.ilkRegistry(), registry);
        assertEq(global.clipperMom(), clipperMom);
    }

    function _mockChainlog(bytes32 key, address value) internal {
        vm.mockCall(CHAINLOG, abi.encodeWithSignature("getAddress(bytes32)", key), abi.encode(value));
    }
}
