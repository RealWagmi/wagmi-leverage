// SPDX-License-Identifier: SAL-1.0
pragma solidity 0.8.23;

library ExternalCall {
    /**
     * @dev Executes a call to the `target` address with the given `data`, gas limit `maxGas`.
     * @param target The address of the contract or external function to call.
     * @param data The calldata to include in the call.
     * @param maxGas The maximum amount of gas to be used for the call. If set to 0, it uses the remaining gas.
     * @return success A boolean indicating whether the call was successful.
     */
    function _externalCall(
        address target,
        bytes calldata data,
        uint256 maxGas
    ) internal returns (bool success) {
        if (maxGas == 0) {
            maxGas = gasleft();
        }
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            calldatacopy(ptr, data.offset, data.length)
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
