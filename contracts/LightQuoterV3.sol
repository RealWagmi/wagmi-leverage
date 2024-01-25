// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.21;

import { IUniswapV3Pool } from "./interfaces/IUniswapV3Pool.sol";
import { SafeCast } from "./vendor0.8/uniswap/SafeCast.sol";
import { Tick } from "./vendor0.8/uniswap/Tick.sol";
import { TickBitmap } from "./vendor0.8/uniswap/TickBitmap.sol";
import { TickMath } from "./vendor0.8/uniswap/TickMath.sol";
import { SwapMath } from "./vendor0.8/uniswap/SwapMath.sol";
import { BitMath } from "./vendor0.8/uniswap/BitMath.sol";

// import "hardhat/console.sol";

contract LightQuoterV3 {
    using SafeCast for uint256;
    using SafeCast for int256;

    // using Tick for mapping(int24 => Tick.Info);
    // using TickBitmap for mapping(int16 => uint256);

    struct Slot0Start {
        uint160 sqrtPriceX96;
        int24 tick;
        uint8 feeProtocol;
    }

    struct SwapCache {
        uint8 feeProtocol;
        uint128 liquidityStart;
        uint24 fee;
        int24 tickSpacing;
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

    function _calcsSwap(
        bool exactInput,
        bool zeroForOne,
        address swapPool,
        int256 amountSpecified, //exactOutput if negative, exactInput if positive
        uint160 sqrtPriceLimitX96
    ) private view returns (uint160 sqrtPriceX96After, int256 amount0, int256 amount1) {
        require(amountSpecified != 0, "AS");

        Slot0Start memory slot0Start;
        {
            (
                // the current price)
                uint160 sqrtPriceX96,
                // the current tick
                int24 tick,
                ,
                ,
                ,
                // the current protocol fee as a percentage of the swap fee taken on withdrawal
                // represented as an integer denominator (1/x)%
                uint8 feeProtocol,

            ) = IUniswapV3Pool(swapPool).slot0();

            slot0Start = Slot0Start(sqrtPriceX96, tick, feeProtocol);

            sqrtPriceLimitX96 = sqrtPriceLimitX96 == 0
                ? (zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1)
                : sqrtPriceLimitX96;

            require(
                zeroForOne
                    ? sqrtPriceLimitX96 < slot0Start.sqrtPriceX96 &&
                        sqrtPriceLimitX96 > TickMath.MIN_SQRT_RATIO
                    : sqrtPriceLimitX96 > slot0Start.sqrtPriceX96 &&
                        sqrtPriceLimitX96 < TickMath.MAX_SQRT_RATIO,
                "SPL"
            );
        }

        SwapCache memory cache = SwapCache({
            liquidityStart: IUniswapV3Pool(swapPool).liquidity(),
            feeProtocol: zeroForOne ? (slot0Start.feeProtocol % 16) : (slot0Start.feeProtocol >> 4),
            fee: IUniswapV3Pool(swapPool).fee(),
            tickSpacing: IUniswapV3Pool(swapPool).tickSpacing()
        });

        SwapState memory state = SwapState({
            amountSpecifiedRemaining: amountSpecified,
            amountCalculated: 0,
            sqrtPriceX96: slot0Start.sqrtPriceX96,
            tick: slot0Start.tick,
            liquidity: cache.liquidityStart
        });

        // continue swapping as long as we haven't used the entire input/output and haven't reached the price limit
        while (state.amountSpecifiedRemaining != 0 && state.sqrtPriceX96 != sqrtPriceLimitX96) {
            StepComputations memory step;

            step.sqrtPriceStartX96 = state.sqrtPriceX96;

            (step.tickNext, step.initialized) = _nextInitializedTickWithinOneWord(
                swapPool,
                state.tick,
                cache.tickSpacing,
                zeroForOne
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
                        zeroForOne
                            ? step.sqrtPriceNextX96 < sqrtPriceLimitX96
                            : step.sqrtPriceNextX96 > sqrtPriceLimitX96
                    )
                        ? sqrtPriceLimitX96
                        : step.sqrtPriceNextX96,
                    state.liquidity,
                    state.amountSpecifiedRemaining,
                    cache.fee
                );

            if (exactInput) {
                // safe because we test that amountSpecified > amountIn + feeAmount in SwapMath
                unchecked {
                    state.amountSpecifiedRemaining -= (step.amountIn + step.feeAmount).toInt256();
                }
                state.amountCalculated -= step.amountOut.toInt256();
            } else {
                unchecked {
                    state.amountSpecifiedRemaining += step.amountOut.toInt256();
                }
                state.amountCalculated += (step.amountIn + step.feeAmount).toInt256();
            }

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

                    (, int128 liquidityNet, , , , , , ) = IUniswapV3Pool(swapPool).ticks(
                        step.tickNext
                    );
                    // if we're moving leftward, we interpret liquidityNet as the opposite sign
                    // safe because liquidityNet cannot be type(int128).min
                    unchecked {
                        if (zeroForOne) liquidityNet = -liquidityNet;
                    }

                    state.liquidity = liquidityNet < 0
                        ? state.liquidity - uint128(-liquidityNet)
                        : state.liquidity + uint128(liquidityNet);
                }

                unchecked {
                    state.tick = zeroForOne ? step.tickNext - 1 : step.tickNext;
                }
            } else if (state.sqrtPriceX96 != step.sqrtPriceStartX96) {
                // recompute unless we're on a lower tick boundary (i.e. already transitioned ticks), and haven't moved
                state.tick = TickMath.getTickAtSqrtRatio(state.sqrtPriceX96);
            }
        }

        unchecked {
            (amount0, amount1) = zeroForOne == exactInput
                ? (amountSpecified - state.amountSpecifiedRemaining, state.amountCalculated)
                : (state.amountCalculated, amountSpecified - state.amountSpecifiedRemaining);
        }
        sqrtPriceX96After = state.sqrtPriceX96;
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

    function quoteExactInputSingle(
        bool zeroForIn,
        address swapPool,
        uint160 sqrtPriceLimitX96,
        uint256 amount
    ) external view returns (uint160 sqrtPriceX96After, uint256 amountOut) {
        int256 amount0;
        int256 amount1;

        (sqrtPriceX96After, amount0, amount1) = _calcsSwap(
            true,
            zeroForIn,
            swapPool,
            amount.toInt256(),
            sqrtPriceLimitX96
        );

        amountOut = zeroForIn ? uint256(-amount1) : uint256(-amount0);
    }
}
