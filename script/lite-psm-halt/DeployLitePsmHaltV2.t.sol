// SPDX-FileCopyrightText: © 2026 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {Test} from "forge-std/Test.sol";

import {LitePsmHaltSpellV2DeployScript} from "./DeployLitePsmHaltV2.s.sol";
import {Flow, LitePsmHaltSpellV2} from "../../src/lite-psm-halt/LitePsmHaltSpellV2.sol";

contract DeployLitePsmHaltV2Test is Test {
    address internal constant CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;
    bytes32 internal constant LITE_PSM_ILK = "LITE-PSM";

    function setUp() public {
        _mockChainlog("MCD_PAUSE", address(1));
    }

    function testNamedEntrypointsUseKnownMomAndExplicitPsm() public {
        address litePsmMom = address(0x51);
        address psm = address(0x52);
        _mockChainlog("LITE_PSM_MOM", litePsmMom);
        vm.mockCall(psm, abi.encodeWithSignature("ilk()"), abi.encode(LITE_PSM_ILK));
        LitePsmHaltSpellV2DeployScript deployer = new LitePsmHaltSpellV2DeployScript();

        LitePsmHaltSpellV2 sell = LitePsmHaltSpellV2(deployer.runSell(psm));
        LitePsmHaltSpellV2 buy = LitePsmHaltSpellV2(deployer.runBuy(psm));
        LitePsmHaltSpellV2 both = LitePsmHaltSpellV2(deployer.runBoth(psm));

        assertEq(sell.litePsmMom(), litePsmMom);
        assertEq(sell.psm(), psm);
        assertEq(uint256(sell.flow()), uint256(Flow.SELL));
        assertEq(uint256(buy.flow()), uint256(Flow.BUY));
        assertEq(uint256(both.flow()), uint256(Flow.BOTH));
    }

    function _mockChainlog(bytes32 key, address value) internal {
        vm.mockCall(CHAINLOG, abi.encodeWithSignature("getAddress(bytes32)", key), abi.encode(value));
    }
}
