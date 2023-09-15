// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.21;

library Keys {
    function addKeyIfNotExists(bytes32[] storage self, bytes32 key) internal {
        bytes32[] memory _self = self;
        bool exists;
        for (uint256 i; i < _self.length; ) {
            if (_self[i] == key) {
                exists = true;
                break;
            }
            unchecked {
                ++i;
            }
        }
        if (!exists) {
            self.push(key);
        }
    }

    function removeKey(bytes32[] storage self, bytes32 key) internal {
        bytes32[] memory _self = self;
        for (uint256 i; i < _self.length; ) {
            if (_self[i] == key) {
                self[i] = _self[_self.length - 1];
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

    function computePairKey(address token0, address token1) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(token0, token1));
    }
}
