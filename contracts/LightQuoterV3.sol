// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.21;

import "./interfaces/ILightQuoterV3.sol";
import { IUniswapV3Pool } from "./interfaces/IUniswapV3Pool.sol";
import { SafeCast } from "./vendor0.8/uniswap/SafeCast.sol";
import { Tick } from "./vendor0.8/uniswap/Tick.sol";
import { TickBitmap } from "./vendor0.8/uniswap/TickBitmap.sol";
import { TickMath } from "./vendor0.8/uniswap/TickMath.sol";
import { SwapMath } from "./vendor0.8/uniswap/SwapMath.sol";
import { BitMath } from "./vendor0.8/uniswap/BitMath.sol";
import { AmountsLiquidity } from "./libraries/AmountsLiquidity.sol";

// import "hardhat/console.sol";

contract LightQuoterV3 is ILightQuoterV3 {
    using SafeCast for uint256;
    using SafeCast for int256;

    uint256 public constant MAX_ITER = 10;

    struct SwapCache {
        bool zeroForOne;
        uint8 feeProtocol;
        uint128 liquidityStart;
        uint24 fee;
        int24 tickSpacing;
        int24 tick;
        uint160 sqrtPriceX96;
        uint160 sqrtPriceX96Limit;
        address swapPool;
    }

    // the top level state of the swap, the results of which are recorded in storage at the end
    struct SwapState {
        // the amount remaining to be swapped in/out of the input/output asset
        int256 amountSpecifiedRemaining;
        // the amount already swapped out/in of the output/input asset
        int256 amountCalculated;
        // current sqrt(price)
        uint160 sqrtPriceX96;
        // the tick associated with the current price
        int24 tick;
        // the current liquidity in range
        uint128 liquidity;
    }

    struct StepComputations {
        // the price at the beginning of the step
        uint160 sqrtPriceStartX96;
        // the next tick to swap to from the current tick in the swap direction
        int24 tickNext;
        // whether tickNext is initialized or not
        bool initialized;
        // sqrt(price) for the next tick (1/0)
        uint160 sqrtPriceNextX96;
        // how much is being swapped in in this step
        uint256 amountIn;
        // how much is being swapped out
        uint256 amountOut;
        // how much fee is being paid in
        uint256 feeAmount;
    }

    function quoteExactInputSingle(
        bool zeroForIn,
        address swapPool,
        uint160 sqrtPriceLimitX96,
        uint256 amountIn
    ) external view returns (uint160 sqrtPriceX96After, uint256 amountOut) {
        SwapCache memory cache = _prepareSwapCashe(zeroForIn, swapPool, sqrtPriceLimitX96);
        return _calcsSwap(amountIn.toInt256(), cache);
    }

    function calculateExactZapIn(
        CalculateExactZapInParams memory params
    )
        external
        view
        returns (
            uint256 i,
            uint160 sqrtPriceX96After,
            uint256 swapAmountIn,
            uint256 swapAmountOut,
            uint256 maxnAmountIn,
            uint256 minAmountOut
        )
    {
        uint160 sqrtRatioAX96 = TickMath.getSqrtRatioAtTick(params.tickLower);
        uint160 sqrtRatioBX96 = TickMath.getSqrtRatioAtTick(params.tickUpper);
        SwapCache memory cache;

        uint256 amountOut;

        uint256 amountInNext;
        (amountInNext, maxnAmountIn, minAmountOut) = _getHoldTokenAmountIn(
            sqrtRatioAX96,
            sqrtRatioBX96,
            params
        );

        if (amountInNext != 0 && params.tokenOutBalance < minAmountOut) {
            (cache) = _prepareSwapCashe(params.zeroForIn, params.swapPool, 0);

            for (i; i < MAX_ITER; ) {
                uint256 amountIn = amountInNext;
                (params.sqrtPriceX96, amountOut) = _calcsSwap(amountIn.toInt256(), cache);

                (amountInNext, maxnAmountIn, minAmountOut) = _getHoldTokenAmountIn(
                    sqrtRatioAX96,
                    sqrtRatioBX96,
                    params
                );

                if (
                    i > 0 &&
                    amountOut + params.tokenOutBalance >= minAmountOut &&
                    maxnAmountIn <= params.tokenInBalance - amountIn
                ) {
                    sqrtPriceX96After = params.sqrtPriceX96;
                    swapAmountIn = amountIn;
                    swapAmountOut = amountOut;
                    break;
                }

                unchecked {
                    ++i;
                }
            }
        }
        require(swapAmountIn > 0 || i == 0, "CALCULATE_ZAP_OUT_FAILED");
        if (!params.zeroForIn) {
            (maxnAmountIn, minAmountOut) = (minAmountOut, maxnAmountIn);
        }
    }

    function _getHoldTokenAmountIn(
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        CalculateExactZapInParams memory params
    ) private pure returns (uint256 holdTokenAmountIn, uint256 maxnAmountIn, uint256 minAmountOut) {
        // Call getAmountsForLiquidity function from LiquidityAmounts library
        // to get the amounts of token0 and token1 for a given liquidity position

        (uint256 amount0, uint256 amount1) = AmountsLiquidity.getAmountsRoundingUpForLiquidity(
            params.sqrtPriceX96,
            sqrtRatioAX96,
            sqrtRatioBX96,
            params.liquidityExactAmount
        );

        // Calculate the holdTokenAmountIn based on the zeroForSaleToken flag
        (holdTokenAmountIn, maxnAmountIn, minAmountOut) = params.zeroForIn
            ? (params.tokenInBalance - amount0, amount0, amount1)
            : (params.tokenInBalance - amount1, amount1, amount0);
    }

    function _prepareSwapCashe(
        bool zeroForOne,
        address swapPool,
        uint160 sqrtPriceLimitX96
    ) private view returns (SwapCache memory cache) {
        (uint160 sqrtPriceX96, int24 tick, , , , uint8 feeProtocol, ) = IUniswapV3Pool(swapPool)
            .slot0();

        if (sqrtPriceLimitX96 != 0) {
            require(
                zeroForOne
                    ? sqrtPriceLimitX96 < sqrtPriceX96 &&
                        sqrtPriceLimitX96 > TickMath.MIN_SQRT_RATIO
                    : sqrtPriceLimitX96 > sqrtPriceX96 &&
                        sqrtPriceLimitX96 < TickMath.MAX_SQRT_RATIO,
                "SQRT_PRICE_LIMIT_EXCEEDS_BOUNDS"
            );
        } else {
            sqrtPriceLimitX96 = zeroForOne
                ? TickMath.MIN_SQRT_RATIO + 1
                : TickMath.MAX_SQRT_RATIO - 1;
        }

        cache = SwapCache({
            zeroForOne: zeroForOne,
            liquidityStart: IUniswapV3Pool(swapPool).liquidity(),
            feeProtocol: zeroForOne ? (feeProtocol % 16) : (feeProtocol >> 4),
            fee: IUniswapV3Pool(swapPool).fee(),
            tickSpacing: IUniswapV3Pool(swapPool).tickSpacing(),
            tick: tick,
            sqrtPriceX96: sqrtPriceX96,
            sqrtPriceX96Limit: sqrtPriceLimitX96,
            swapPool: swapPool
        });
    }

    function _calcsSwap(
        int256 amountIn,
        SwapCache memory cache
    ) private view returns (uint160, uint256) {
        require(amountIn != 0, "CALCULATE_SWAP_AMOUNT_IN_ZERO");
        SwapState memory state = SwapState({
            amountSpecifiedRemaining: amountIn,
            amountCalculated: 0,
            sqrtPriceX96: cache.sqrtPriceX96,
            tick: cache.tick,
            liquidity: cache.liquidityStart
        });
        // continue swapping as long as we haven't used the entire input/output and haven't reached the price limit
        while (
            state.amountSpecifiedRemaining != 0 && state.sqrtPriceX96 != cache.sqrtPriceX96Limit
        ) {
            StepComputations memory step;

            step.sqrtPriceStartX96 = state.sqrtPriceX96;

            (step.tickNext, step.initialized) = _nextInitializedTickWithinOneWord(
                cache.swapPool,
                state.tick,
                cache.tickSpacing,
                cache.zeroForOne
            );

            // ensure that we do not overshoot the min/max tick, as the tick bitmap is not aware of these bounds
            if (step.tickNext < TickMath.MIN_TICK) {
                step.tickNext = TickMath.MIN_TICK;
            } else if (step.tickNext > TickMath.MAX_TICK) {
                step.tickNext = TickMath.MAX_TICK;
            }

            // get the price for the next tick
            step.sqrtPriceNextX96 = TickMath.getSqrtRatioAtTick(step.tickNext);

            // compute values to swap to the target tick, price limit, or point where input/output amount is exhausted
            (state.sqrtPriceX96, step.amountIn, step.amountOut, step.feeAmount) = SwapMath
                .computeSwapStep(
                    state.sqrtPriceX96,
                    (
                        cache.zeroForOne
                            ? step.sqrtPriceNextX96 < cache.sqrtPriceX96Limit
                            : step.sqrtPriceNextX96 > cache.sqrtPriceX96Limit
                    )
                        ? cache.sqrtPriceX96Limit
                        : step.sqrtPriceNextX96,
                    state.liquidity,
                    state.amountSpecifiedRemaining,
                    cache.fee
                );

            // safe because we test that amountSpecified > amountIn + feeAmount in SwapMath
            unchecked {
                state.amountSpecifiedRemaining -= (step.amountIn + step.feeAmount).toInt256();
            }
            state.amountCalculated -= step.amountOut.toInt256();

            // if the protocol fee is on, calculate how much is owed, decrement feeAmount, and increment protocolFee
            if (cache.feeProtocol > 0) {
                unchecked {
                    uint256 delta = step.feeAmount / cache.feeProtocol;
                    step.feeAmount -= delta;
                }
            }

            // shift tick if we reached the next price
            if (state.sqrtPriceX96 == step.sqrtPriceNextX96) {
                // if the tick is initialized, run the tick transition
                if (step.initialized) {
                    // check for the placeholder value, which we replace with the actual value the first time the swap
                    // crosses an initialized tick

                    (, int128 liquidityNet, , , , , , ) = IUniswapV3Pool(cache.swapPool).ticks(
                        step.tickNext
                    );
                    // if we're moving leftward, we interpret liquidityNet as the opposite sign
                    // safe because liquidityNet cannot be type(int128).min
                    unchecked {
                        if (cache.zeroForOne) liquidityNet = -liquidityNet;
                    }

                    state.liquidity = liquidityNet < 0
                        ? state.liquidity - uint128(-liquidityNet)
                        : state.liquidity + uint128(liquidityNet);
                }

                unchecked {
                    state.tick = cache.zeroForOne ? step.tickNext - 1 : step.tickNext;
                }
            } else if (state.sqrtPriceX96 != step.sqrtPriceStartX96) {
                // recompute unless we're on a lower tick boundary (i.e. already transitioned ticks), and haven't moved
                state.tick = TickMath.getTickAtSqrtRatio(state.sqrtPriceX96);
            }
        }
        return (state.sqrtPriceX96, uint256(-state.amountCalculated));
    }

    function _position(int24 tick) private pure returns (int16 wordPos, uint8 bitPos) {
        unchecked {
            wordPos = int16(tick >> 8);
            bitPos = uint8(int8(tick % 256));
        }
    }

    function _nextInitializedTickWithinOneWord(
        address swapPool,
        int24 tick,
        int24 tickSpacing,
        bool lte
    ) private view returns (int24 next, bool initialized) {
        unchecked {
            int24 compressed = tick / tickSpacing;
            if (tick < 0 && tick % tickSpacing != 0) compressed--; // round towards negative infinity

            if (lte) {
                (int16 wordPos, uint8 bitPos) = _position(compressed);
                // all the 1s at or to the right of the current bitPos
                uint256 mask = (1 << bitPos) - 1 + (1 << bitPos);
                uint256 masked = IUniswapV3Pool(swapPool).tickBitmap(wordPos) & mask;

                // if there are no initialized ticks to the right of or at the current tick, return rightmost in the word
                initialized = masked != 0;
                // overflow/underflow is possible, but prevented externally by limiting both tickSpacing and tick
                next = initialized
                    ? (compressed - int24(uint24(bitPos - BitMath.mostSignificantBit(masked)))) *
                        tickSpacing
                    : (compressed - int24(uint24(bitPos))) * tickSpacing;
            } else {
                // start from the word of the next tick, since the current tick state doesn't matter
                (int16 wordPos, uint8 bitPos) = _position(compressed + 1);
                // all the 1s at or to the left of the bitPos
                uint256 mask = ~((1 << bitPos) - 1);
                uint256 masked = IUniswapV3Pool(swapPool).tickBitmap(wordPos) & mask;

                // if there are no initialized ticks to the left of the current tick, return leftmost in the word
                initialized = masked != 0;
                // overflow/underflow is possible, but prevented externally by limiting both tickSpacing and tick
                next = initialized
                    ? (compressed +
                        1 +
                        int24(uint24(BitMath.leastSignificantBit(masked) - bitPos))) * tickSpacing
                    : (compressed + 1 + int24(uint24(type(uint8).max - bitPos))) * tickSpacing;
            }
        }
    }
}
