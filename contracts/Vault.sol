// SPDX-License-Identifier: SAL-1.0

/**
 * WAGMI  Leverage Protocol Vault v2.0
 * wagmi.com
 */

pragma solidity 0.8.23;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IVault.sol";
import "./interfaces/IWagmiLeverageFlashCallback.sol";
import "./vendor0.8/uniswap/FullMath.sol";
import { TransferHelper } from "./libraries/TransferHelper.sol";

contract Vault is Ownable, IVault {
    using TransferHelper for address;

    uint24 private immutable maxFlashFee;

    mapping(address => uint24) public flashFeeForToken;

    constructor(uint24 _maxFlashFee) {
        maxFlashFee = _maxFlashFee;
    }

    function setFlashFee(address token, uint24 flashFee) external onlyOwner {
        require(flashFee <= maxFlashFee, "V-FE");
        flashFeeForToken[token] = flashFee;
    }

    function vaultFlash(address token, uint256 amount, bytes calldata data) external onlyOwner {
        uint256 balanceBefore = token.getBalance();

        if (balanceBefore < amount) amount = balanceBefore;
        uint256 feeAmt;
        if (amount > 0) {
            uint24 flashFee = flashFeeForToken[token];
            if (flashFee == 0) {
                flashFee = maxFlashFee;
            }
            feeAmt = FullMath.mulDivRoundingUp(amount, flashFee, 1e6);
            token.safeTransfer(msg.sender, amount);
            balanceBefore += feeAmt;
        }

        IWagmiLeverageFlashCallback(msg.sender).wagmiLeverageFlashCallback(amount, feeAmt, data);
        uint256 balanceAfter = token.getBalance();
        require(balanceBefore <= balanceAfter, "V-FL");

        if (amount > 0) emit VaultFlash(token, amount, feeAmt);
    }

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
