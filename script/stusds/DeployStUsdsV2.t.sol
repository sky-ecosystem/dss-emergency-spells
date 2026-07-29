// SPDX-FileCopyrightText: © 2026 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {Test} from "forge-std/Test.sol";

import {
    StUsdsRateSetterDissBudSpellV2DeployScript,
    StUsdsRateSetterHaltSpellV2DeployScript,
    StUsdsWipeParamSpellV2DeployScript
} from "./DeployStUsdsV2.s.sol";
import {StUsdsRateSetterDissBudSpellV2} from "../../src/stusds/StUsdsRateSetterDissBudSpellV2.sol";
import {StUsdsRateSetterHaltSpellV2} from "../../src/stusds/StUsdsRateSetterHaltSpellV2.sol";
import {Param, StUsdsWipeParamSpellV2} from "../../src/stusds/StUsdsWipeParamSpellV2.sol";

contract DeployStUsdsV2Test is Test {
    address internal constant CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;
    bytes32 internal constant STUSDS_ILK = "STUSDS";

    function setUp() public {
        _mockChainlog("MCD_PAUSE", address(1));
        _mockChainlog("MCD_VAT", address(2));
    }

    function testChainlogRateSetterEntrypointsKeepBudExplicit() public {
        (address mom, address rateSetter, address stUsds) = _mockStUsds();
        address bud = address(0x85);

        StUsdsRateSetterDissBudSpellV2 diss =
            StUsdsRateSetterDissBudSpellV2(new StUsdsRateSetterDissBudSpellV2DeployScript().run(bud));
        StUsdsRateSetterHaltSpellV2 halt =
            StUsdsRateSetterHaltSpellV2(new StUsdsRateSetterHaltSpellV2DeployScript().run());

        assertEq(diss.stUsdsMom(), mom);
        assertEq(diss.rateSetter(), rateSetter);
        assertEq(diss.stUsds(), stUsds);
        assertEq(diss.bud(), bud);
        assertEq(halt.stUsdsMom(), mom);
        assertEq(halt.rateSetter(), rateSetter);
    }

    function testNamedWipeEntrypoints() public {
        (,, address stUsds) = _mockStUsds();
        vm.mockCall(stUsds, abi.encodeWithSignature("ilk()"), abi.encode(STUSDS_ILK));
        StUsdsWipeParamSpellV2DeployScript deployer = new StUsdsWipeParamSpellV2DeployScript();

        StUsdsWipeParamSpellV2 cap = StUsdsWipeParamSpellV2(deployer.runCap());
        StUsdsWipeParamSpellV2 line = StUsdsWipeParamSpellV2(deployer.runLine());
        StUsdsWipeParamSpellV2 both = StUsdsWipeParamSpellV2(deployer.runBoth());

        assertEq(uint256(cap.param()), uint256(Param.CAP));
        assertEq(uint256(line.param()), uint256(Param.LINE));
        assertEq(uint256(both.param()), uint256(Param.BOTH));
    }

    function _mockStUsds() internal returns (address mom, address rateSetter, address stUsds) {
        mom = address(0x81);
        rateSetter = address(0x82);
        stUsds = address(0x83);
        _mockChainlog("STUSDS_MOM", mom);
        _mockChainlog("STUSDS_RATE_SETTER", rateSetter);
        _mockChainlog("STUSDS", stUsds);
        vm.mockCall(mom, abi.encodeWithSignature("stusds()"), abi.encode(stUsds));
        vm.mockCall(rateSetter, abi.encodeWithSignature("stusds()"), abi.encode(stUsds));
    }

    function _mockChainlog(bytes32 key, address value) internal {
        vm.mockCall(CHAINLOG, abi.encodeWithSignature("getAddress(bytes32)", key), abi.encode(value));
    }
}
