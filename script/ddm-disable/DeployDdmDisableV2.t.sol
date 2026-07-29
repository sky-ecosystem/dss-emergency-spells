// SPDX-FileCopyrightText: © 2026 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {Test} from "forge-std/Test.sol";

import {DdmDisableSpellV2DeployScript} from "./DeployDdmDisableV2.s.sol";
import {DdmDisableSpellV2} from "../../src/ddm-disable/DdmDisableSpellV2.sol";

contract DeployDdmDisableV2Test is Test {
    address internal constant CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;

    function setUp() public {
        _mockChainlog("MCD_PAUSE", address(1));
    }

    function testExplicitAndChainlogEntrypointsKeepPlanExplicit() public {
        address ddmMom = address(0x41);
        address plan = address(0x42);
        bytes32 ilk = "DIRECT-SPARK-DAI";
        _mockChainlog("DIRECT_MOM", ddmMom);

        DdmDisableSpellV2 explicitSpell = DdmDisableSpellV2(new DdmDisableSpellV2DeployScript().run(ddmMom, plan, ilk));
        DdmDisableSpellV2 chainlogSpell = DdmDisableSpellV2(new DdmDisableSpellV2DeployScript().run(plan, ilk));

        assertEq(explicitSpell.ddmMom(), ddmMom);
        assertEq(chainlogSpell.ddmMom(), ddmMom);
        assertEq(chainlogSpell.plan(), plan);
        assertEq(chainlogSpell.ilk(), ilk);
    }

    function _mockChainlog(bytes32 key, address value) internal {
        vm.mockCall(CHAINLOG, abi.encodeWithSignature("getAddress(bytes32)", key), abi.encode(value));
    }
}
