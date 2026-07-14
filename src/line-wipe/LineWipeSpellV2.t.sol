// SPDX-FileCopyrightText: © 2026 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";

import {EmergencySpellBatchV2} from "../EmergencySpellBatchV2.sol";
import {LineWipeSpellV2} from "./LineWipeSpellV2.sol";

contract LineWipeVatMockV2 {
    mapping(bytes32 => uint256) public line;

    function setLine(bytes32 ilk, uint256 line_) external {
        line[ilk] = line_;
    }

    function ilks(bytes32 ilk)
        external
        view
        returns (uint256 Art, uint256 rate, uint256 spot, uint256 line_, uint256 dust)
    {
        return (0, 0, 0, line[ilk], 0);
    }
}

contract LineWipeAutoLineMockV2 {
    struct Config {
        uint256 maxLine;
        uint256 gap;
        uint48 ttl;
        uint48 last;
        uint48 lastInc;
    }

    mapping(bytes32 => Config) internal configs;

    function set(bytes32 ilk) external {
        configs[ilk] = Config({maxLine: 200, gap: 50, ttl: 1 hours, last: 10, lastInc: 11});
    }

    function clear(bytes32 ilk) external {
        delete configs[ilk];
    }

    function ilks(bytes32 ilk)
        external
        view
        returns (uint256 maxLine, uint256 gap, uint48 ttl, uint48 last, uint48 lastInc)
    {
        Config memory config = configs[ilk];
        return (config.maxLine, config.gap, config.ttl, config.last, config.lastInc);
    }
}

contract LineWipeMomMockV2 {
    address public immutable autoLine;
    LineWipeVatMockV2 internal immutable vat;
    mapping(address => bool) public authorized;
    address public lastCaller;

    event Wiped(bytes32 indexed ilk, address indexed caller);

    constructor(address autoLine_, address vat_) {
        autoLine = autoLine_;
        vat = LineWipeVatMockV2(vat_);
    }

    function rely(address caller) external {
        authorized[caller] = true;
    }

    function wipe(bytes32 ilk) external returns (uint256) {
        require(authorized[msg.sender], "LineWipeMomMockV2/not-authorized");
        lastCaller = msg.sender;
        LineWipeAutoLineMockV2(autoLine).clear(ilk);
        vat.setLine(ilk, 0);
        emit Wiped(ilk, msg.sender);
        return 0;
    }
}

contract BrokenLineWipeMomMockV2 {
    address public immutable autoLine;

    constructor(address autoLine_) {
        autoLine = autoLine_;
    }
}

contract LineWipeSpellV2Test is Test {
    address internal constant CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;
    bytes32 internal constant MCD_PAUSE = "MCD_PAUSE";
    bytes32 internal constant MCD_VAT = "MCD_VAT";
    bytes32 internal constant ILK = "ETH-A";

    LineWipeVatMockV2 internal vat;
    LineWipeAutoLineMockV2 internal autoLine;
    LineWipeMomMockV2 internal lineMom;
    LineWipeSpellV2 internal spell;

    function setUp() public {
        vat = new LineWipeVatMockV2();
        autoLine = new LineWipeAutoLineMockV2();
        lineMom = new LineWipeMomMockV2(address(autoLine), address(vat));
        vm.mockCall(CHAINLOG, abi.encodeWithSignature("getAddress(bytes32)", MCD_PAUSE), abi.encode(makeAddr("pause")));
        vm.mockCall(CHAINLOG, abi.encodeWithSignature("getAddress(bytes32)", MCD_VAT), abi.encode(address(vat)));
        vat.setLine(ILK, 100);
        autoLine.set(ILK);
        spell = new LineWipeSpellV2(address(lineMom), ILK);
    }

    function testMetadataAndInitialState() public view {
        assertEq(spell.description(), string(abi.encodePacked("Emergency Spell | Line Wipe: ", ILK)));
        assertEq(spell.lineMom(), address(lineMom));
        assertEq(spell.autoLine(), address(autoLine));
        assertEq(spell.vat(), address(vat));
        assertEq(spell.ilk(), ILK);
        assertFalse(spell.done());
    }

    function testUnauthorizedExecutionDoesNotChangeState() public {
        vm.expectRevert("LineWipeMomMockV2/not-authorized");
        spell.schedule();
        assertFalse(spell.done());
        assertEq(vat.line(ILK), 100);
    }

    function testDirectExecutionIsRepeatable() public {
        lineMom.rely(address(spell));
        vm.recordLogs();
        spell.schedule();
        _assertOnlyDownstreamEvent(vm.getRecordedLogs(), address(spell));
        assertTrue(spell.done());
        spell.schedule();
        assertTrue(spell.done());
        assertEq(lineMom.lastCaller(), address(spell));
    }

    function testBatchExecutionUsesBatchAsCaller() public {
        address[] memory leaves = new address[](1);
        leaves[0] = address(spell);
        EmergencySpellBatchV2 batch = new EmergencySpellBatchV2(leaves, "Line wipe");
        lineMom.rely(address(batch));

        vm.recordLogs();
        batch.schedule();
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 batchEvents;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter == address(batch)) ++batchEvents;
        }
        assertEq(batchEvents, 1);
        _assertDownstreamEvent(logs);

        assertTrue(spell.done());
        assertTrue(batch.done());
        assertEq(lineMom.lastCaller(), address(batch));
    }

    function testDoneIncludesVatLine() public {
        lineMom.rely(address(spell));
        spell.schedule();
        assertTrue(spell.done());
        vat.setLine(ILK, 1);
        assertFalse(spell.done());
    }

    function testMalformedAutoLineRevertsInsteadOfReportingDone() public {
        BrokenLineWipeMomMockV2 brokenMom = new BrokenLineWipeMomMockV2(makeAddr("invalid-auto-line"));
        LineWipeSpellV2 brokenSpell = new LineWipeSpellV2(address(brokenMom), ILK);
        vm.expectRevert();
        brokenSpell.done();
    }

    function _assertOnlyDownstreamEvent(Vm.Log[] memory logs, address leaf) internal {
        for (uint256 i; i < logs.length; ++i) {
            assertTrue(logs[i].emitter != leaf);
        }
        _assertDownstreamEvent(logs);
    }

    function _assertDownstreamEvent(Vm.Log[] memory logs) internal {
        bytes32 signature = keccak256("Wiped(bytes32,address)");
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter == address(lineMom) && logs[i].topics[0] == signature) return;
        }
        fail();
    }
}
