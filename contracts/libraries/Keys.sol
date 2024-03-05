// SPDX-License-Identifier: SAL-1.0
pragma solidity 0.8.23;

library Keys {
    /**
     * @dev Computes the borrowing key based on the borrower's address, sale token address, and hold token address.
     * @param borrower The address of the borrower.
     * @param saleToken The address of the sale token.
     * @param holdToken The address of the hold token.
     * @return The computed borrowing key as a bytes32 value.
     */
    function computeBorrowingKey(
        address borrower,
        address saleToken,
        address holdToken
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(borrower, saleToken, holdToken));
    }

    /**
     * @dev Computes the pair key based on the sale token address and hold token address.
     * @param saleToken The address of the sale token.
     * @param holdToken The address of the hold token.
     * @return The computed pair key as a bytes32 value.
     */
    function computePairKey(address saleToken, address holdToken) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(saleToken, holdToken));
    }
}
