// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

// Interface for the Vault contract
interface IVault {
    event VaultFlash(address token, uint256 amount, uint256 fee);

    // Function to transfer tokens from the vault to a specified address
    function transferToken(address _token, address _to, uint256 _amount) external;

    function vaultFlash(address token, uint256 amount, bytes calldata data) external;

    function setFlashFee(address token, uint24 flashFee) external;

    // Function to get the balances of multiple tokens
    function getBalances(
        address[] calldata tokens
    ) external view returns (uint256[] memory balances);

    function flashFeeForToken(address token) external view returns (uint24);
}
