// SPDX-License-Identifier: SAL-1.0

/**
 * wagmi.com
 */

pragma solidity 0.8.23;

import { IUniswapV3Factory } from "./IUniswapV3Factory.sol";

interface IBestInternalPool {
    function getBestInternalPoolByInput(
        uint256 amountIn,
        IUniswapV3Factory _underlyingV3Factory,
        address saleToken,
        address holdToken,
        uint24[] memory supportedFees
    ) external view returns (uint256 amountOut, address pool, uint24 fee);

    function getBestInternalPoolByOutput(
        uint256 amountOut,
        IUniswapV3Factory _underlyingV3Factory,
        address saleToken,
        address holdToken,
        uint24[] memory supportedFees
    ) external view returns (uint256 amountIn, address pool, uint24 fee);
}
