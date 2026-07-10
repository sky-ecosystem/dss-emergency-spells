// SPDX-FileCopyrightText: © 2026 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {Test} from "forge-std/Test.sol";

import {EmergencySpellV2} from "../src/EmergencySpellV2.sol";

contract ContractTarget {}

contract EmergencySpellV2Harness is EmergencySpellV2 {
    string public constant override description = "Emergency Spell | V2 Harness";
    bool public constant override done = false;

    event EmergencyAction(address caller);

    function _emergencyActions() internal override {
        emit EmergencyAction(msg.sender);
    }
}

contract ContractValidationHarness is EmergencySpellV2Harness {
    constructor(address target) {
        _requireContract(target);
    }
}

contract EmergencySpellV2Test is Test {
    address internal constant CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;
    bytes32 internal constant MCD_PAUSE = "MCD_PAUSE";

    ContractTarget internal pause;
    EmergencySpellV2Harness internal spell;

    event EmergencyAction(address caller);

    function setUp() public {
        pause = new ContractTarget();
        vm.mockCall(CHAINLOG, abi.encodeWithSignature("getAddress(bytes32)", MCD_PAUSE), abi.encode(address(pause)));
        spell = new EmergencySpellV2Harness();
    }

    function testCompatibilitySurface() public view {
        assertEq(spell.pause(), address(pause));
        assertEq(spell.log(), CHAINLOG);
        assertEq(spell.action(), address(spell));
        assertEq(spell.eta(), 0);
        assertEq(spell.sig(), abi.encodeWithSignature("execute()"));
        assertEq(spell.expiration(), type(uint256).max);
        assertFalse(spell.officeHours());
        assertEq(spell.nextCastTime(), type(uint256).max);
        assertEq(spell.nextCastTime(123), type(uint256).max);
        assertEq(spell.description(), "Emergency Spell | V2 Harness");
        assertFalse(spell.done());
        assertEq(spell.tag(), address(spell).codehash);
    }

    function testScheduleExecutesImmediatelyAsOriginalCaller() public {
        address caller = makeAddr("caller");

        vm.expectEmit(false, false, false, true);
        emit EmergencyAction(caller);
        vm.prank(caller);
        spell.schedule();
    }

    function testRegularSpellActionFunctionsAreNoOps() public {
        spell.cast();
        spell.execute();
        spell.actions();
    }

    function testBaseDoesNotWriteNormalStorage() public view {
        for (uint256 slot; slot < 8; ++slot) {
            assertEq(vm.load(address(spell), bytes32(slot)), bytes32(0));
        }
    }

    function testContractValidationAcceptsDeployedContract() public {
        new ContractValidationHarness(address(new ContractTarget()));
    }

    function testContractValidationRejectsZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(EmergencySpellV2.InvalidContract.selector, address(0)));
        new ContractValidationHarness(address(0));
    }

    function testContractValidationRejectsAddressWithoutCode() public {
        address eoa = makeAddr("eoa");

        vm.expectRevert(abi.encodeWithSelector(EmergencySpellV2.InvalidContract.selector, eoa));
        new ContractValidationHarness(eoa);
    }

    function testConstructorRejectsInvalidPauseFromChainlog() public {
        address invalidPause = makeAddr("invalid-pause");
        vm.mockCall(CHAINLOG, abi.encodeWithSignature("getAddress(bytes32)", MCD_PAUSE), abi.encode(invalidPause));

        vm.expectRevert(abi.encodeWithSelector(EmergencySpellV2.InvalidContract.selector, invalidPause));
        new EmergencySpellV2Harness();
    }
}
