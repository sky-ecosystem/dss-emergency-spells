// SPDX-FileCopyrightText: © 2026 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.16;

library DescriptionLibV2 {
    /// @notice Converts a null-terminated bytes32 value into a string.
    function toString(bytes32 value) internal pure returns (string memory) {
        uint256 length;
        while (length < 32 && value[length] != 0) {
            unchecked {
                ++length;
            }
        }

        bytes memory result = new bytes(length);
        for (uint256 i; i < length; ++i) {
            result[i] = value[i];
        }
        return string(result);
    }
}
