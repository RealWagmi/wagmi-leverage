// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.21;

struct CalculateZapOutParams {
    address swapPool;
    bool zeroForIn;
    uint160 sqrtPriceX96;
    int24 tickLower;
    int24 tickUpper;
    uint128 desiredLiquidity;
    uint256 tokenInBalance;
    uint256 tokenOutBalance;
}

interface ILightQuoterV3 {
    function calculateZapOut(
        CalculateZapOutParams memory params
    )
        external
        view
        returns (
            uint256 iterations,
            uint160 sqrtPriceX96After,
            uint256 swapAmountIn,
            uint256 swapAmountOut
        );

    function quoteExactInputSingle(
        bool zeroForIn,
        address swapPool,
        uint160 sqrtPriceLimitX96,
        uint256 amountIn
    ) external view returns (uint160 sqrtPriceX96After, uint256 amountOut);
}
