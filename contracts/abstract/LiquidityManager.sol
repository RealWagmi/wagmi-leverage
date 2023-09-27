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
        bool isEmergency;
        bool zeroForSaleToken;
        uint24 fee;
        uint256 slippageBP1000;
        uint256 totalfeesOwed;
        uint256 totalBorrowedAmount;
    }

    struct RestoreLiquidityCache {
        uint128 borrowedLiquidity;
        int24 tickLower;
        int24 tickUpper;
        uint24 fee;
        address saleToken;
        address holdToken;
        uint160 sqrtPriceX96;
        uint256 tokenId;
        uint256 holdTokenDebt;
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

    /**
     * @dev Extracts liquidity from loans and returns the borrowed amount.
     * @param zeroForSaleToken Boolean flag indicating whether the first token passed is the token being sold.
     * @param token0 The address of one of the tokens in the pair.
     * @param token1 The address of the other token in the pair.
     * @param loans An array of Loan struct instances containing loan information.
     * @return borrowedAmount The total amount borrowed.
     */
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
            // Extract position-related details
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
                    // Check operator approval
                    if (operator != address(this)) {
                        revert NotApproved(tokenId);
                    }
                    // Check token validity
                    if (posToken0 != token0 || posToken1 != token1) {
                        revert InvalidTokens(tokenId);
                    }
                }
                // Check borrowed liquidity validity
                if (!(liquidity > 0 && liquidity <= posLiquidity)) {
                    revert InvalidBorrowedLiquidity(tokenId);
                }
                // Calculate borrowed amount
                borrowedAmount += _getSingleSideBorrowedAmount(
                    zeroForSaleToken,
                    tickLower,
                    tickUpper,
                    liquidity
                );
            }
            // Decrease liquidity and move to the next loan
            _decreaseLiquidity(tokenId, liquidity);

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev Restores liquidity from loans.
     * @param params The RestoreLiquidityParams struct containing restoration parameters.
     * @param externalSwap The SwapParams struct containing external swap details.
     * @param loans An array of Loan struct instances containing loan information.
     */
    function _restoreLiquidity(
        RestoreLiquidityParams memory params,
        SwapParams calldata externalSwap,
        Loan[] memory loans
    ) internal {
        RestoreLiquidityCache memory cache;
        for (uint256 i; i < loans.length; ) {
            // Update the cache for the current loan
            _upCache(params.zeroForSaleToken, loans[i].liquidity, loans[i].tokenId, cache);

            (uint256 holdTokenAmountIn, uint256 amount0, uint256 amount1) = _getHoldTokenAmountIn(
                params.zeroForSaleToken,
                cache.tickLower,
                cache.tickUpper,
                cache.sqrtPriceX96,
                cache.borrowedLiquidity,
                cache.holdTokenDebt
            );

            if (holdTokenAmountIn > 0) {
                // Quote exact input single for swap
                uint256 saleTokenAmountOut;
                (saleTokenAmountOut, cache.sqrtPriceX96, , ) = underlyingQuoterV2
                    .quoteExactInputSingle(
                        IQuoterV2.QuoteExactInputSingleParams({
                            tokenIn: cache.holdToken,
                            tokenOut: cache.saleToken,
                            amountIn: holdTokenAmountIn,
                            fee: params.fee,
                            sqrtPriceLimitX96: 0
                        })
                    );
                // Perform external swap if external swap target is provided
                if (externalSwap.swapTarget != address(0)) {
                    _patchAmountsAndCallSwap(
                        cache.holdToken,
                        cache.saleToken,
                        externalSwap,
                        holdTokenAmountIn,
                        (saleTokenAmountOut * params.slippageBP1000) / Constants.BPS
                    );
                } else {
                    // Calculate hold token amount in again for new sqrtPriceX96
                    (holdTokenAmountIn, , ) = _getHoldTokenAmountIn(
                        params.zeroForSaleToken,
                        cache.tickLower,
                        cache.tickUpper,
                        cache.sqrtPriceX96,
                        cache.borrowedLiquidity,
                        cache.holdTokenDebt
                    );
                    // Perform v3 swap exact input and update sqrtPriceX96
                    _v3SwapExactInput(
                        v3SwapExactInputParams({
                            fee: params.fee,
                            tokenIn: cache.holdToken,
                            tokenOut: cache.saleToken,
                            amountIn: holdTokenAmountIn,
                            amountOutMinimum: (saleTokenAmountOut * params.slippageBP1000) /
                                Constants.BPS
                        })
                    );
                    cache.sqrtPriceX96 = _getCurrentSqrtPriceX96(
                        params.zeroForSaleToken,
                        cache.saleToken,
                        cache.holdToken,
                        cache.fee
                    );
                    (amount0, amount1) = LiquidityAmounts.getAmountsForLiquidity(
                        cache.sqrtPriceX96,
                        TickMath.getSqrtRatioAtTick(cache.tickLower),
                        TickMath.getSqrtRatioAtTick(cache.tickUpper),
                        cache.borrowedLiquidity
                    );
                }
            }

            address creditor = underlyingPositionManager.ownerOf(cache.tokenId);
            // Increase liquidity and transfer liquidity owner reward
            _increaseLiquidity(
                params.isEmergency,
                creditor,
                cache.saleToken,
                cache.holdToken,
                cache.borrowedLiquidity,
                cache.tokenId,
                amount0 + 1,
                amount1 + 1
            );

            uint256 liquidityOwnerReward = (params.totalfeesOwed * cache.holdTokenDebt) /
                params.totalBorrowedAmount /
                Constants.COLLATERAL_BALANCE_PRECISION;
            Vault(VAULT_ADDRESS).transferToken(cache.holdToken, creditor, liquidityOwnerReward);

            unchecked {
                ++i;
            }
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
        bool isEmergency,
        address creditor,
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

            if (!(isEmergency && msg.sender == creditor)) {
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
    }

    function _getHoldTokenAmountIn(
        bool zeroForSaleToken,
        int24 tickLower,
        int24 tickUpper,
        uint160 sqrtPriceX96,
        uint128 liquidity,
        uint256 holdTokenDebt
    ) private pure returns (uint256 holdTokenAmountIn, uint256 amount0, uint256 amount1) {
        (amount0, amount1) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtPriceX96,
            TickMath.getSqrtRatioAtTick(tickLower),
            TickMath.getSqrtRatioAtTick(tickUpper),
            liquidity
        );
        holdTokenAmountIn = holdTokenDebt - ((zeroForSaleToken ? amount1 : amount0) + 1);
    }

    /**
     * @dev Updates the cache for liquidity restoration.
     * @param zeroForSaleToken A boolean indicating whether the zero token is for sale.
     * @param liquidity The liquidity amount of the loan.
     * @param tokenId The ID of the token associated with the loan.
     * @param cache The RestoreLiquidityCache struct instance to update.
     */
    function _upCache(
        bool zeroForSaleToken,
        uint128 liquidity,
        uint256 tokenId,
        RestoreLiquidityCache memory cache
    ) private view {
        cache.tokenId = tokenId;
        cache.borrowedLiquidity = liquidity;
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

        ) = underlyingPositionManager.positions(tokenId);

        if (!zeroForSaleToken) {
            (cache.saleToken, cache.holdToken) = (cache.holdToken, cache.saleToken);
        }

        cache.holdTokenDebt = _getSingleSideBorrowedAmount(
            zeroForSaleToken,
            cache.tickLower,
            cache.tickUpper,
            cache.borrowedLiquidity
        );
        cache.sqrtPriceX96 = _getCurrentSqrtPriceX96(
            zeroForSaleToken,
            cache.saleToken,
            cache.holdToken,
            cache.fee
        );
    }
}
