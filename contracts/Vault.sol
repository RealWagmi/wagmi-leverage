// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.21;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IVault.sol";

contract Vault is Ownable, IVault {
    using SafeERC20 for IERC20;

    /**
     * @notice Transfers tokens to a specified address
     * @param _token The address of the token to be transferred
     * @param _to The address to which the tokens will be transferred
     * @param _amount The amount of tokens to be transferred
     */
    function transferToken(address _token, address _to, uint256 _amount) external onlyOwner {
        if (_amount > 0) {
            IERC20(_token).safeTransfer(_to, _amount);
        }
    }

    function getBalances(
        address[] calldata tokens
    ) external view returns (uint256[] memory balances) {
        bytes memory callData = abi.encodeWithSelector(IERC20.balanceOf.selector, address(this));
        uint256 length = tokens.length;
        balances = new uint256[](length);
        for (uint256 i; i < length; ) {
            (bool success, bytes memory data) = tokens[i].staticcall(callData);
            require(success && data.length >= 32);
            balances[i] = abi.decode(data, (uint256));
            unchecked {
                ++i;
            }
        }
    }
}
