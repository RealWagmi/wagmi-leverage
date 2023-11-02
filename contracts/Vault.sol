// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.21;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IVault.sol";
import { TransferHelper } from "./libraries/TransferHelper.sol";

contract Vault is Ownable, IVault {
    using TransferHelper for address;

    /**
     * @notice Transfers tokens to a specified address
     * @param _token The address of the token to be transferred
     * @param _to The address to which the tokens will be transferred
     * @param _amount The amount of tokens to be transferred
     */
    function transferToken(address _token, address _to, uint256 _amount) external onlyOwner {
        if (_amount > 0) {
            _token.safeTransfer(_to, _amount);
        }
    }

    /**
     * @dev Retrieves the balances of multiple tokens for this contract.
     * @param tokens The array of token addresses for which to retrieve the balances.
     * @return balances An array of uint256 values representing the balances of the corresponding tokens in the `tokens` array.
     */
    function getBalances(
        address[] calldata tokens
    ) external view returns (uint256[] memory balances) {
        uint256 length = tokens.length;
        balances = new uint256[](length);
        for (uint256 i; i < length; ) {
            balances[i] = tokens[i].getBalance();
            unchecked {
                ++i;
            }
        }
    }
}
