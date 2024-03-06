// SPDX-License-Identifier: SAL-1.0

/**
 * WAGMI  Leverage Protocol Vault v2.0
 * wagmi.com
 */

pragma solidity 0.8.23;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IVault.sol";
import "./interfaces/IUniswapV3FlashCallback.sol";
import "./vendor0.8/uniswap/FullMath.sol";
import { TransferHelper } from "./libraries/TransferHelper.sol";

contract Vault is Ownable, IVault {
    using TransferHelper for address;

    uint256 private immutable maxFlashFee;

    mapping(address => uint256) public flashFeeForToken;

    constructor(uint256 _maxFlashFee) {
        maxFlashFee = _maxFlashFee;
    }

    function setFlashFee(address token, uint256 flashFee) external onlyOwner {
        require(flashFee <= maxFlashFee, "WV-FE");
        flashFeeForToken[token] = flashFee;
    }

    function vaultFlash(
        bool zeroForFlash,
        address token,
        uint256 amount,
        bytes calldata data
    ) external onlyOwner {
        uint256 balanceBefore = token.getBalance();

        if (balanceBefore < amount) amount = balanceBefore;
        uint256 feeAmt;
        if (amount > 0) {
            uint256 flashFee = flashFeeForToken[token];
            if (flashFee == 0) {
                flashFee = maxFlashFee;
            }
            feeAmt = FullMath.mulDivRoundingUp(amount, flashFee, 1e6);
            token.safeTransfer(msg.sender, amount);
            balanceBefore += feeAmt;
        }
        (uint256 fee0, uint256 fee1) = zeroForFlash ? (feeAmt, uint256(0)) : (uint256(0), feeAmt);
        IUniswapV3FlashCallback(msg.sender).uniswapV3FlashCallback(fee0, fee1, data);
        uint256 balanceAfter = token.getBalance();
        require(balanceBefore <= balanceAfter, "WV-FL");

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
