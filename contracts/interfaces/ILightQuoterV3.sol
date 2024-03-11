// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title Light Quoter Interface
interface ILightQuoterV3 {
    /// @title Struct for "Zap In" Calculation Parameters
    /// @notice This struct encapsulates the various parameters required for calculating the exact amount of tokens to zap in.
    struct CalculateExactZapInParams {
        /// @notice The address of the swap pool where liquidity will be added.
        address swapPool;
        /// @notice A boolean determining which token will be used to add liquidity (true for token0 or false for token1).
        bool zeroForIn;
        /// @notice The lower bound of the tick range for the position within the pool.
        int24 tickLower;
        /// @notice The upper bound of the tick range for the position within the pool.
        int24 tickUpper;
        /// @notice The exact amount of liquidity to add to the pool.
        uint128 liquidityExactAmount;
        /// @notice The balance of the token that will be used to add liquidity.
        uint256 tokenInBalance;
        /// @notice The balance of the other token in the pool, not typically used for adding liquidity directly but necessary for calculations.
        uint256 tokenOutBalance;
    }

    /// @notice Calculates parameters related to "zapping in" to a position with an exact amount of liquidity.
    /// @dev Interacts with an on-chain liquidity pool to precisely estimate the amounts in/out to add liquidity.
    ///      This calculation is performed using iterative methods to ensure the exactness of the resulting values.
    ///      It uses the `getSqrtRatioAtTick` method within the loop to determine price bounds.
    ///      This process is designed to avoid failure due to constraints such as limited input or other conditions.
    ///      The number of iterations to reach an accurate result is bounded by a maximum value.
    /// @param params A `CalculateExactZapInParams` struct containing all necessary parameters to perform the calculations.
    ///               This may include details about the liquidity pool, desired position, slippage tolerance, etc.
    /// @return swapAmountIn The exact total amount of input tokens required to complete the zap in operation.
    /// @return amount0 The exact amount of the token0 will be used for "zapping in" to a position.
    /// @return amount1 The exact amount of the token1 will be used for "zapping in" to a position.
    function calculateExactZapIn(
        CalculateExactZapInParams memory params
    ) external view returns (uint256 swapAmountIn, uint256 amount0, uint256 amount1);

    /**
     * @notice Quotes the output amount for a given input amount in a single token swap operation on Uniswap V3.
     * @dev This function simulates the swap and returns the estimated output amount. It does not execute the trade itself.
     * @param zeroForIn A boolean indicating the direction of the swap:
     * true for swapping the 0th token (token0) to the 1st token (token1), false for token1 to token0.
     * @param swapPool The address of the Uniswap V3 pool contract through which the swap will be simulated.
     * @param amountIn The amount of input tokens that one would like to swap.
     * @return sqrtPriceX96After The square root of the price after the swap, scaled by 2^96. This is the price between the two tokens in the pool post-simulation.
     * @return amountOut The amount of output tokens that can be expected to receive in the swap based on the current state of the pool.
     */
    function quoteExactInputSingle(
        bool zeroForIn,
        address swapPool,
        uint256 amountIn
    ) external view returns (uint160 sqrtPriceX96After, uint256 amountOut);

    /**
     * @notice Quotes the amount of input tokens required to arrive at a specified output token amount for a single pool swap.
     * @dev This function performs a read-only operation to compute the necessary input amount and does not execute an actual swap.
     *      It is useful for obtaining quotes prior to performing transactions.
     * @param zeroForIn A boolean that indicates the direction of the trade, true if swapping zero for in-token, false otherwise.
     * @param swapPool The address of the swap pool contract where the trade will take place.
     * @param amountOut The desired amount of output tokens.
     * @return sqrtPriceX96After The square root price (encoded as a 96-bit fixed point number) after the swap would occur.
     * @return amountIn The amount of input tokens required for the swap to achieve the desired `amountOut`.
     */
    function quoteExactOutputSingle(
        bool zeroForIn,
        address swapPool,
        uint256 amountOut
    ) external view returns (uint160 sqrtPriceX96After, uint256 amountIn);
}
