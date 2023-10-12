// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

library ExternalCall {
    /**
     * @dev Executes a call to the `target` address with the given `data`, gas limit `maxGas`, and optional patching of a swapAmount value.
     * @param target The address of the contract or external function to call.
     * @param data The calldata to include in the call.
     * @param maxGas The maximum amount of gas to be used for the call. If set to 0, it uses the remaining gas.
     * @param swapAmountInDataIndex The index at which to patch the `swapAmountInDataValue` in the calldata.
     * @param swapAmountInDataValue The value to be patched at the specified index in the calldata. Can be 0 to skip patching.
     * @return success A boolean indicating whether the call was successful.
     */
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

    /**
     * @dev Reads the first 4 bytes from the given `swapData` parameter and returns them as a bytes4 value.
     * @param swapData The calldata containing the data to read the first 4 bytes from.
     * @return result The first 4 bytes of the `swapData` as a bytes4 value.
     */
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
