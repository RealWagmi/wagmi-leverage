// SPDX-License-Identifier: SAL-1.0

/**
 * wagmi.com
 */

pragma solidity 0.8.21;

import {IUniswapV3Factory} from "./interfaces/IUniswapV3Factory.sol";
import {ILightQuoterV3WithImpact} from "./interfaces/ILightQuoterV3WithImpact.sol";

contract BestInternalPool {

    ILightQuoterV3WithImpact public immutable quoter;

    constructor(ILightQuoterV3WithImpact _quoter) {
        quoter = _quoter;
    }

    function getBestInternalPoolByInput(
        uint256 amountIn,
        IUniswapV3Factory _underlyingV3Factory,
        address saleToken,
        address holdToken,
        uint24[] memory supportedFees
    ) external view returns (uint256 amountOut, address pool, uint24 fee) {
        bool zeroForIn = saleToken < holdToken;
        address tokenA = zeroForIn ? saleToken : holdToken;
        address tokenB = zeroForIn ? holdToken : saleToken;
        for (uint256 i = 0; i < supportedFees.length; i++) {
            address poolAddress = _underlyingV3Factory.getPool(tokenA, tokenB, supportedFees[i]);
            if (poolAddress != address(0)) {
                (bool reached, , uint buffAmountOut) = quoter.quoteExactInputSingle(
                    zeroForIn,
                    poolAddress,
                    amountIn
                );
                if (reached) {
                    continue;
                }
                if (buffAmountOut > amountOut) {
                    amountOut = buffAmountOut;
                    pool = poolAddress;
                    fee = supportedFees[i];
                }
            }
        }
        
    }

    function getBestInternalPoolByOutput(
        uint256 amountOut,
        IUniswapV3Factory _underlyingV3Factory,
        address saleToken,
        address holdToken,
        uint24[] memory supportedFees
    ) external view returns (uint256 amountIn, address pool, uint24 fee) {
        bool zeroForIn = saleToken < holdToken;
        address tokenA = zeroForIn ? saleToken : holdToken;
        address tokenB = zeroForIn ? holdToken : saleToken;
        amountIn = type(uint256).max;
        for (uint256 i = 0; i < supportedFees.length; i++) {
            address poolAddress = _underlyingV3Factory.getPool(tokenA, tokenB, supportedFees[i]);
            if (poolAddress != address(0)) {
                (bool reached, , uint buffAmountIn) = quoter.quoteExactOutputSingle(
                    zeroForIn,
                    poolAddress,
                    amountOut
                );
                if (reached) {
                    continue;
                }
                if (buffAmountIn < amountIn) {
                    amountIn = buffAmountIn;
                    pool = poolAddress;
                    fee = supportedFees[i];
                }
            }
        }
    }
}