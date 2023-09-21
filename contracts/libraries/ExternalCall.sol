// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

/// @title Constant state
library ExternalCall {
    function _patchAmountAndCall(
        address target,
        bytes calldata data,
        uint256 maxGas,
        uint256 swapAmountInDataIndex,
        uint256 swapAmountInDataValue
    ) internal returns (bool success) {
        if (maxGas == 0) {
            maxGas = gasleft();
        }
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            calldatacopy(ptr, data.offset, data.length)
            if gt(swapAmountInDataValue, 0) {
                mstore(add(add(ptr, 0x24), mul(swapAmountInDataIndex, 0x20)), swapAmountInDataValue)
            }
            success := call(
                maxGas,
                target,
                0, //value
                ptr, //Inputs are stored at location ptr
                data.length,
                0,
                0
            )

            if and(not(success), and(gt(returndatasize(), 0), lt(returndatasize(), 256))) {
                returndatacopy(ptr, 0, returndatasize())
                revert(ptr, returndatasize())
            }

            mstore(0x40, add(ptr, data.length)) // Set storage pointer to empty space
        }
    }

    function _readFirstBytes4(bytes calldata swapData) internal pure returns (bytes4 result) {
        // Read the bytes4 from array memory
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            calldatacopy(ptr, swapData.offset, 32)
            result := mload(ptr)
            // Solidity does not require us to clean the trailing bytes.
            // We do it anyway
            result := and(
                result,
                0xFFFFFFFF00000000000000000000000000000000000000000000000000000000
            )
        }
        return result;
    }
}
