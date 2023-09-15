// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;
import "../vendor0.8/uniswap/LiquidityAmounts.sol";
import "../vendor0.8/uniswap/TickMath.sol";
import "../interfaces/INonfungiblePositionManager.sol";
import "./ApproveSwapAndPay.sol";
import "../Vault.sol";
import { Constants } from "../libraries/Constants.sol";

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

    constructor(
        address _underlyingPositionManagerAddress,
        address _underlyingV3Factory,
        bytes32 _underlyingV3PoolInitCodeHash
    ) ApproveSwapAndPay(_underlyingV3Factory, _underlyingV3PoolInitCodeHash) {
        underlyingPositionManager = INonfungiblePositionManager(_underlyingPositionManagerAddress);
        bytes32 salt = keccak256(abi.encode(block.timestamp, address(this)));
        VAULT_ADDRESS = address(new Vault{ salt: salt }());
    }

    error InvalidBorrowedLiquidity(uint256 tokenId);
    error InvalidTokens(uint256 tokenId);
    error NotApproved(uint256 tokenId);
    error InvalidRestoredLiquidity(
        uint256 tokenId,
        uint128 restoredLiquidity,
        uint128 borrowedLiquidity,
        uint256 amount0,
        uint256 amount1
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
        address token0,
        address token1,
        uint24 fee
    ) private view returns (uint160 sqrtPriceX96) {
        address poolAddress = computePoolAddress(token0, token1, fee);
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
            revert InvalidRestoredLiquidity(
                tokenId,
                restoredLiquidity,
                liquidityDesired,
                amount0,
                amount1
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

    function _prepare(
        bool zeroForSaleToken,
        uint24 swappingPoolFee,
        uint128 liquidity,
        uint256 tokenId
    )
        private
        view
        returns (
            uint256 holdTokenDebt,
            uint256 amountHoldTokenToSwap,
            uint160 swappingSqrtPriceX96,
            address posToken0,
            address posToken1
        )
    {
        uint160 sqrtPriceX96;

        int24 tickLower;
        int24 tickUpper;
        {
            uint24 fee;
            (
                ,
                ,
                posToken0,
                posToken1,
                fee,
                tickLower,
                tickUpper,
                ,
                ,
                ,
                ,

            ) = underlyingPositionManager.positions(tokenId);

            holdTokenDebt = _getSingleSideBorrowedAmount(
                zeroForSaleToken,
                tickLower,
                tickUpper,
                liquidity
            );

            sqrtPriceX96 = _getCurrentSqrtPriceX96(posToken0, posToken1, fee);

            if (swappingPoolFee != fee) {
                swappingSqrtPriceX96 = _getCurrentSqrtPriceX96(
                    posToken0,
                    posToken1,
                    swappingPoolFee
                );
            } else {
                swappingSqrtPriceX96 = sqrtPriceX96;
            }
        }

        (uint256 amount0, uint256 amount1) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtPriceX96,
            TickMath.getSqrtRatioAtTick(tickLower),
            TickMath.getSqrtRatioAtTick(tickUpper),
            liquidity
        );
        amountHoldTokenToSwap = _getAmountHoldTokenToSwap(
            zeroForSaleToken,
            swappingSqrtPriceX96,
            holdTokenDebt,
            amount0,
            amount1
        );
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

    function _restoreLiquidity(RestoreLiquidityParams memory params, Loan[] memory loans) internal {
        for (uint256 i; i < loans.length; ) {
            uint256 tokenId = loans[i].tokenId;
            uint128 borrowedLiquidity = loans[i].liquidity;

            (
                uint256 holdTokenDebt,
                uint256 amountHoldTokenToSwap,
                uint160 swappingSqrtPriceX96,
                address posToken0,
                address posToken1
            ) = _prepare(params.zeroForSaleToken, params.fee, borrowedLiquidity, tokenId);
            {
                uint256 amountOut;

                if (amountHoldTokenToSwap > 0) {
                    amountOut =
                        (_getAmountOut(
                            !params.zeroForSaleToken,
                            amountHoldTokenToSwap,
                            swappingSqrtPriceX96
                        ) * params.slippageBP1000) /
                        Constants.BPS;
                    amountOut = _v3SwapExactInput(
                        v3SwapExactInputParams({
                            fee: params.fee,
                            tokenIn: params.zeroForSaleToken ? posToken1 : posToken0,
                            tokenOut: params.zeroForSaleToken ? posToken0 : posToken1,
                            amountIn: amountHoldTokenToSwap,
                            amountOutMinimum: amountOut
                        })
                    );
                }
                _increaseLiquidity(
                    borrowedLiquidity,
                    tokenId,
                    holdTokenDebt - amountHoldTokenToSwap,
                    amountOut
                );
            }
            uint256 liquidityOwnerReward = (params.totalfeesOwed * holdTokenDebt) /
                params.totalBorrowedAmount;
            address holdToken = params.zeroForSaleToken ? posToken0 : posToken1;
            Vault(VAULT_ADDRESS).transferToken(
                holdToken,
                underlyingPositionManager.ownerOf(tokenId),
                liquidityOwnerReward
            );

            unchecked {
                ++i;
            }
        }
    }
}
