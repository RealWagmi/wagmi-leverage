// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

/// @title Constant state
library ExternalCall {
    function _patchAmountAndCall(
        address target,
        uint256 maxGas,
        bytes calldata data,
        uint256 index,
        uint256 value
    ) internal returns (bool success) {
        if (maxGas == 0) {
            maxGas = gasleft();
        }
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            calldatacopy(ptr, data.offset, data.length)
            mstore(add(add(ptr, 0x24), mul(index, 0x20)), value)
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
}
