// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.21;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

abstract contract HelperContract {
    /**
     * @dev This internal function attempts to approve a specific amount of tokens for a spender.
     * It performs a call to the `approve` function on the token contract using the provided parameters,
     * and returns a boolean indicating whether the approval was successful or not.
     * @param token The address of the token contract.
     * @param spender The address of the spender.
     * @param amount The amount of tokens to be approved.
     * @return A boolean indicating whether the approval was successful or not.
     */
    function _tryApprove(address token, address spender, uint256 amount) private returns (bool) {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.approve.selector, spender, amount)
        );
        return success && (data.length == 0 || abi.decode(data, (bool)));
    }

    /**
     * @dev This internal function ensures that the allowance for a spender is at least the specified amount.
     * If the current allowance is less than the specified amount, it attempts to approve the maximum possible value,
     * and if that fails, it retries with the maximum possible value minus one. If both attempts fail,
     * it reverts with an error indicating that the approval did not succeed.
     * @param token The address of the token contract.
     * @param spender The address of the spender.
     * @param amount The minimum required allowance.
     */
    function _maxApproveIfNecessary(address token, address spender, uint256 amount) internal {
        if (IERC20(token).allowance(address(this), spender) < amount) {
            if (!_tryApprove(token, spender, type(uint256).max)) {
                if (!_tryApprove(token, spender, type(uint256).max - 1)) {
                    require(_tryApprove(token, spender, 0));
                    if (!_tryApprove(token, spender, type(uint256).max)) {
                        if (!_tryApprove(token, spender, type(uint256).max - 1)) {
                            revert("ERC20_APPROVE_DID_NOT_SUCCEED");
                        }
                    }
                }
            }
        }
    }
}
