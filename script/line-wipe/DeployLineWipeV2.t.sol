// SPDX-FileCopyrightText: © 2026 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {Test} from "forge-std/Test.sol";

import {GlobalLineWipeSpellV2DeployScript, LineWipeSpellV2DeployScript} from "./DeployLineWipeV2.s.sol";
import {GlobalLineWipeSpellV2} from "../../src/line-wipe/GlobalLineWipeSpellV2.sol";
import {LineWipeSpellV2} from "../../src/line-wipe/LineWipeSpellV2.sol";

contract DeployLineWipeV2Test is Test {
    address internal constant CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;
    bytes32 internal constant ILK = "ETH-A";

    function setUp() public {
        _mockChainlog("MCD_PAUSE", address(1));
        _mockChainlog("MCD_VAT", address(2));
    }

    function testExplicitAndChainlogEntrypoints() public {
        address lineMom = address(0x11);
        address autoLine = address(0x12);
        address registry = address(0x13);
        vm.mockCall(lineMom, abi.encodeWithSignature("autoLine()"), abi.encode(autoLine));
        _mockChainlog("LINE_MOM", lineMom);
        _mockChainlog("ILK_REGISTRY", registry);

        LineWipeSpellV2 explicitLeaf = LineWipeSpellV2(new LineWipeSpellV2DeployScript().run(lineMom, ILK));
        LineWipeSpellV2 chainlogLeaf = LineWipeSpellV2(new LineWipeSpellV2DeployScript().run(ILK));
        GlobalLineWipeSpellV2 global = GlobalLineWipeSpellV2(new GlobalLineWipeSpellV2DeployScript().run());

        assertEq(explicitLeaf.lineMom(), lineMom);
        assertEq(chainlogLeaf.lineMom(), lineMom);
        assertEq(chainlogLeaf.ilk(), ILK);
        assertEq(global.ilkRegistry(), registry);
        assertEq(global.lineMom(), lineMom);
    }

    function _mockChainlog(bytes32 key, address value) internal {
        vm.mockCall(CHAINLOG, abi.encodeWithSignature("getAddress(bytes32)", key), abi.encode(value));
    }
}
