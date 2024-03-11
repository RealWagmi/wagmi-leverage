// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

interface IApproveSwapAndPay {
    /// @notice Struct representing the parameters for a Uniswap V3 exact input swap.
    struct v3SwapExactParams {
        bool isExactInput;
        /// @dev The fee tier to be used for the swap.
        uint24 fee;
        /// @dev The address of the token to be swapped from.
        address tokenIn;
        /// @dev The address of the token to be swapped to.
        address tokenOut;
        /// @dev The amount of `tokenIn/tokenOut` to be swapped.
        uint256 amount;
    }

    /// @notice Struct to hold parameters for swapping tokens
    struct SwapParams {
        /// @notice Address of the aggregator's router
        address swapTarget;
        /// @notice The maximum gas limit for the swap call
        uint256 maxGasForCall;
        /// @notice The aggregator's data that stores paths and amounts for swapping through
        bytes swapData;
    }

    function computePoolAddress(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external view returns (address);

    function swapIsWhitelisted(
        address swapTarget,
        bytes4 selector
    ) external view returns (bool IsWhitelisted);
}
