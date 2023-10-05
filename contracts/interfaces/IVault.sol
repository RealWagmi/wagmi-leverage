// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.21;

interface IVault {
    function transferToken(address _token, address _to, uint256 _amount) external;

    function getBalances(
        address[] calldata tokens
    ) external view returns (uint256[] memory balances);
}
