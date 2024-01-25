// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.21;

interface ILightQuoterV3 {
    function quoteExactInputSingle(
        bool zeroForIn,
        address swapPool,
        uint160 sqrtPriceLimitX96,
        uint256 amount
    ) external view returns (uint160 sqrtPriceX96After, uint256 amountOut);
}
