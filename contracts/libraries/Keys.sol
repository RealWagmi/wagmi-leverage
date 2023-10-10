// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.21;
import "@openzeppelin/contracts/utils/Arrays.sol";

library Keys {
    using Arrays for bytes32[];

    function addKeyIfNotExists(bytes32[] storage self, bytes32 key) internal {
        uint256 length = self.length;
        for (uint256 i; i < length; ) {
            if (self.unsafeAccess(i).value == key) {
                return;
            }
            unchecked {
                ++i;
            }
        }
        self.push(key);
    }

    function removeKey(bytes32[] storage self, bytes32 key) internal {
        uint256 length = self.length;
        for (uint256 i; i < length; ) {
            if (self.unsafeAccess(i).value == key) {
                self.unsafeAccess(i).value = self.unsafeAccess(length - 1).value;
                self.pop();
                break;
            }
            unchecked {
                ++i;
            }
        }
    }

    function computeBorrowingKey(
        address borrower,
        address saleToken,
        address holdToken
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(borrower, saleToken, holdToken));
    }

    function computePairKey(address saleToken, address holdToken) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(saleToken, holdToken));
    }
}
