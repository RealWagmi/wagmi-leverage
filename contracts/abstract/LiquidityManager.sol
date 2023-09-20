// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;
import "../vendor0.8/uniswap/LiquidityAmounts.sol";
import "../vendor0.8/uniswap/Babylonian.sol";
import "../vendor0.8/uniswap/TickMath.sol";
import "../interfaces/INonfungiblePositionManager.sol";
import "../interfaces/IQuoterV2.sol";
import "./ApproveSwapAndPay.sol";
import "../Vault.sol";
import { Constants } from "../libraries/Constants.sol";

// import "hardhat/console.sol";

abstract contract LiquidityManager is ApproveSwapAndPay {
    struct Loan {
        uint128 liquidity;
        uint256 tokenId;
    }

    struct RestoreLiquidityParams {
        bool zeroForSaleToken;
        uint24 fee;
        uint256 slippageBP1000;
        uint256 totalfeesOwed;
        uint256 totalBorrowedAmount;
    }

    address public immutable VAULT_ADDRESS;
    INonfungiblePositionManager public immutable underlyingPositionManager;
    IQuoterV2 public immutable underlyingQuoterV2;

    constructor(
        address _underlyingPositionManagerAddress,
        address _underlyingQuoterV2,
        address _underlyingV3Factory,
        bytes32 _underlyingV3PoolInitCodeHash
    ) ApproveSwapAndPay(_underlyingV3Factory, _underlyingV3PoolInitCodeHash) {
        underlyingPositionManager = INonfungiblePositionManager(_underlyingPositionManagerAddress);
        underlyingQuoterV2 = IQuoterV2(_underlyingQuoterV2);
        bytes32 salt = keccak256(abi.encode(block.timestamp, address(this)));
        VAULT_ADDRESS = address(new Vault{ salt: salt }());
    }

    error InvalidBorrowedLiquidity(uint256 tokenId);
    error InvalidTokens(uint256 tokenId);
    error NotApproved(uint256 tokenId);
    error InvalidRestoredLiquidity(
        uint256 tokenId,
        uint128 borrowedLiquidity,
        uint128 restoredLiquidity,
        uint256 amount0,
        uint256 amount1,
        uint256 holdTokentBalance,
        uint256 saleTokenBalance
    );

    function _getSingleSideBorrowedAmount(
        bool zeroForSaleToken,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity
    ) private pure returns (uint256 borrowedAmount) {
        borrowedAmount =
            (
                zeroForSaleToken
                    ? LiquidityAmounts.getAmount1ForLiquidity(
                        TickMath.getSqrtRatioAtTick(tickLower),
                        TickMath.getSqrtRatioAtTick(tickUpper),
                        liquidity
                    )
                    : LiquidityAmounts.getAmount0ForLiquidity(
                        TickMath.getSqrtRatioAtTick(tickLower),
                        TickMath.getSqrtRatioAtTick(tickUpper),
                        liquidity
                    )
            ) +
            1;
    }

    function _getAmountOut(
        bool zeroForIn,
        uint256 amountIn,
        uint160 sqrtPriceX96
    ) private pure returns (uint256 amountOut) {
        if (sqrtPriceX96 <= type(uint128).max) {
            uint256 ratioX192 = uint256(sqrtPriceX96) * sqrtPriceX96;
            amountOut = zeroForIn
                ? FullMath.mulDiv(ratioX192, amountIn, 1 << 192)
                : FullMath.mulDiv(1 << 192, amountIn, ratioX192);
        } else {
            uint256 ratioX128 = FullMath.mulDiv(sqrtPriceX96, sqrtPriceX96, 1 << 64);
            amountOut = zeroForIn
                ? FullMath.mulDiv(ratioX128, amountIn, 1 << 128)
                : FullMath.mulDiv(1 << 128, amountIn, ratioX128);
        }
    }

    function _getCurrentSqrtPriceX96(
        bool zeroForA,
        address tokenA,
        address tokenB,
        uint24 fee
    ) private view returns (uint160 sqrtPriceX96) {
        if (!zeroForA) {
            (tokenA, tokenB) = (tokenB, tokenA);
        }
        address poolAddress = computePoolAddress(tokenA, tokenB, fee);
        (sqrtPriceX96, , , , , , ) = IUniswapV3Pool(poolAddress).slot0();
        // (, int24 tick, , , , , ) = IUniswapV3Pool(poolAddress).slot0();
        // sqrtPriceX96 = TickMath.getSqrtRatioAtTick(tick);
    }

    function _getPairBalance(
        address tokenA,
        address tokenB
    ) internal view returns (uint256 balanceA, uint256 balanceB) {
        bytes memory callData = abi.encodeWithSelector(IERC20.balanceOf.selector, address(this));
        (bool success, bytes memory data) = tokenA.staticcall(callData);
        require(success && data.length >= 32);
        balanceA = abi.decode(data, (uint256));
        (success, data) = tokenB.staticcall(callData);
        require(success && data.length >= 32);
        balanceB = abi.decode(data, (uint256));
    }

    function _decreaseLiquidity(uint256 tokenId, uint128 liquidity) private {
        (uint256 amount0, uint256 amount1) = underlyingPositionManager.decreaseLiquidity(
            INonfungiblePositionManager.DecreaseLiquidityParams({
                tokenId: tokenId,
                liquidity: liquidity,
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp
            })
        );
        if (amount0 == 0 && amount1 == 0) {
            revert InvalidBorrowedLiquidity(tokenId);
        }

        (amount0, amount1) = underlyingPositionManager.collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: tokenId,
                recipient: address(this),
                amount0Max: uint128(amount0),
                amount1Max: uint128(amount1)
            })
        );
    }

    function _increaseLiquidity(
        address saleToken,
        address holdTokent,
        uint128 liquidityDesired,
        uint256 tokenId,
        uint256 amount0,
        uint256 amount1
    ) private {
        (uint128 restoredLiquidity, , ) = underlyingPositionManager.increaseLiquidity(
            INonfungiblePositionManager.IncreaseLiquidityParams({
                tokenId: tokenId,
                amount0Desired: amount0,
                amount1Desired: amount1,
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp
            })
        );

        if (restoredLiquidity < liquidityDesired) {
            (uint256 holdTokentBalance, uint256 saleTokenBalance) = _getPairBalance(
                holdTokent,
                saleToken
            );
            revert InvalidRestoredLiquidity(
                tokenId,
                liquidityDesired,
                restoredLiquidity,
                amount0,
                amount1,
                holdTokentBalance,
                saleTokenBalance
            );
        }
    }

    function _getAmountHoldTokenToSwap(
        bool zeroForSaleToken,
        uint160 swappingSqrtPriceX96,
        uint256 holdTokenDebt,
        uint256 amount0,
        uint256 amount1
    ) private pure returns (uint256 amountHoldTokenToSwap) {
        if (amount0 > 0 && amount1 > 0) {
            if (zeroForSaleToken) {
                uint256 outToken0 = _getAmountOut(false, holdTokenDebt, swappingSqrtPriceX96);
                if (outToken0 > 0) {
                    uint256 denominator = FullMath.mulDiv(
                        amount1 * outToken0,
                        FixedPoint96.Q96,
                        amount0 * holdTokenDebt
                    ) + FixedPoint96.Q96;

                    amountHoldTokenToSwap = FullMath.mulDiv(
                        holdTokenDebt,
                        FixedPoint96.Q96,
                        denominator
                    );
                }
            } else {
                uint256 outToken1 = _getAmountOut(true, holdTokenDebt, swappingSqrtPriceX96);
                if (outToken1 > 0) {
                    uint256 denominator = FullMath.mulDiv(
                        amount0 * outToken1,
                        FixedPoint96.Q96,
                        amount1 * holdTokenDebt
                    ) + FixedPoint96.Q96;

                    amountHoldTokenToSwap = FullMath.mulDiv(
                        holdTokenDebt,
                        FixedPoint96.Q96,
                        denominator
                    );
                }
            }
        } else {
            if ((zeroForSaleToken && amount1 == 0) || (!zeroForSaleToken && amount0 == 0)) {
                amountHoldTokenToSwap = holdTokenDebt;
            }
        }
    }

    function _extractLiquidity(
        bool zeroForSaleToken,
        address token0,
        address token1,
        Loan[] memory loans
    ) internal returns (uint256 borrowedAmount) {
        if (!zeroForSaleToken) {
            (token0, token1) = (token1, token0);
        }

        for (uint256 i; i < loans.length; ) {
            uint256 tokenId = loans[i].tokenId;
            uint128 liquidity = loans[i].liquidity;
            {
                int24 tickLower;
                int24 tickUpper;
                uint128 posLiquidity;
                {
                    address operator;
                    address posToken0;
                    address posToken1;

                    (
                        ,
                        operator,
                        posToken0,
                        posToken1,
                        ,
                        tickLower,
                        tickUpper,
                        posLiquidity,
                        ,
                        ,
                        ,

                    ) = underlyingPositionManager.positions(tokenId);

                    if (operator != address(this)) {
                        revert NotApproved(tokenId);
                    }

                    if (posToken0 != token0 || posToken1 != token1) {
                        revert InvalidTokens(tokenId);
                    }
                }

                if (!(liquidity > 0 && liquidity <= posLiquidity)) {
                    revert InvalidBorrowedLiquidity(tokenId);
                }
                borrowedAmount += _getSingleSideBorrowedAmount(
                    zeroForSaleToken,
                    tickLower,
                    tickUpper,
                    liquidity
                );
            }

            _decreaseLiquidity(tokenId, liquidity);

            unchecked {
                ++i;
            }
        }
    }

    struct RestoreLiquidityCache {
        uint128 borrowedLiquidity;
        int24 tickLower;
        int24 tickUpper;
        uint24 fee;
        address saleToken;
        address holdToken;
        uint256 tokenId;
    }

    function _getHoldTokenAmountIn(
        bool zeroForSaleToken,
        int24 tickLower,
        int24 tickUpper,
        uint160 sqrtPriceX96,
        uint128 liquidity,
        uint256 holdTokenDebt
    ) internal pure returns (uint256 holdTokenAmountIn, uint256 amount0, uint256 amount1) {
        (amount0, amount1) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtPriceX96,
            TickMath.getSqrtRatioAtTick(tickLower),
            TickMath.getSqrtRatioAtTick(tickUpper),
            liquidity
        );
        holdTokenAmountIn = holdTokenDebt - ((zeroForSaleToken ? amount1 : amount0) + 1);
    }

    function _restoreLiquidity(RestoreLiquidityParams memory params, Loan[] memory loans) internal {
        RestoreLiquidityCache memory cache;
        for (uint256 i; i < loans.length; ) {
            cache.tokenId = loans[i].tokenId;
            cache.borrowedLiquidity = loans[i].liquidity;
            (
                ,
                ,
                cache.saleToken,
                cache.holdToken,
                cache.fee,
                cache.tickLower,
                cache.tickUpper,
                ,
                ,
                ,
                ,

            ) = underlyingPositionManager.positions(cache.tokenId);

            if (!params.zeroForSaleToken) {
                (cache.saleToken, cache.holdToken) = (cache.holdToken, cache.saleToken);
            }

            uint256 holdTokenDebt = _getSingleSideBorrowedAmount(
                params.zeroForSaleToken,
                cache.tickLower,
                cache.tickUpper,
                cache.borrowedLiquidity
            );

            uint160 sqrtPriceX96 = _getCurrentSqrtPriceX96(
                params.zeroForSaleToken,
                cache.saleToken,
                cache.holdToken,
                cache.fee
            );

            (uint256 holdTokenAmountIn, uint256 amount0, uint256 amount1) = _getHoldTokenAmountIn(
                params.zeroForSaleToken,
                cache.tickLower,
                cache.tickUpper,
                sqrtPriceX96,
                cache.borrowedLiquidity,
                holdTokenDebt
            );

            if (holdTokenAmountIn > 0) {
                uint256 saleTokenAmountOut;
                (saleTokenAmountOut, sqrtPriceX96, , ) = underlyingQuoterV2.quoteExactInputSingle(
                    IQuoterV2.QuoteExactInputSingleParams({
                        tokenIn: cache.holdToken,
                        tokenOut: cache.saleToken,
                        amountIn: holdTokenAmountIn,
                        fee: params.fee,
                        sqrtPriceLimitX96: 0
                    })
                );

                (holdTokenAmountIn, , ) = _getHoldTokenAmountIn(
                    params.zeroForSaleToken,
                    cache.tickLower,
                    cache.tickUpper,
                    sqrtPriceX96,
                    cache.borrowedLiquidity,
                    holdTokenDebt
                );

                saleTokenAmountOut = _v3SwapExactInput(
                    v3SwapExactInputParams({
                        fee: params.fee,
                        tokenIn: cache.holdToken,
                        tokenOut: cache.saleToken,
                        amountIn: holdTokenAmountIn,
                        amountOutMinimum: (saleTokenAmountOut * params.slippageBP1000) /
                            Constants.BPS
                    })
                );

                sqrtPriceX96 = _getCurrentSqrtPriceX96(
                    params.zeroForSaleToken,
                    cache.saleToken,
                    cache.holdToken,
                    cache.fee
                );
                (amount0, amount1) = LiquidityAmounts.getAmountsForLiquidity(
                    sqrtPriceX96,
                    TickMath.getSqrtRatioAtTick(cache.tickLower),
                    TickMath.getSqrtRatioAtTick(cache.tickUpper),
                    cache.borrowedLiquidity
                );
            }

            _increaseLiquidity(
                cache.saleToken,
                cache.holdToken,
                cache.borrowedLiquidity,
                cache.tokenId,
                amount0 + 1,
                amount1 + 1
            );

            uint256 liquidityOwnerReward = (params.totalfeesOwed * holdTokenDebt) /
                params.totalBorrowedAmount;
            Vault(VAULT_ADDRESS).transferToken(
                cache.holdToken,
                underlyingPositionManager.ownerOf(cache.tokenId),
                liquidityOwnerReward
            );

            unchecked {
                ++i;
            }
        }
    }
}
