// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.23;
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/ILightQuoterV3.sol";
import { IUniswapV3Pool } from "./interfaces/IUniswapV3Pool.sol";
import { SafeCast } from "./vendor0.8/uniswap/SafeCast.sol";
import { TickMath } from "./vendor0.8/uniswap/TickMath.sol";
import { SwapMath } from "./vendor0.8/uniswap/SwapMath.sol";
import { BitMath } from "./vendor0.8/uniswap/BitMath.sol";
import { AmountsLiquidity } from "./libraries/AmountsLiquidity.sol";

// import "hardhat/console.sol";

contract LightQuoterV3 is ILightQuoterV3 {
    using SafeCast for uint256;

    uint256 public constant MAX_ITER = 15;

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

    error LtQV3ZapInFailed(
        uint256 amountInNext,
        uint256 calcAmountIn,
        uint256 calcAmountOut,
        uint256 tokenInBalance,
        uint256 tokenOutBalance
    );

    function quoteExactInputSingle(
        bool zeroForIn,
        address swapPool,
        uint256 amountIn
    ) external view returns (uint160 sqrtPriceX96After, uint256 amountOut) {
        SwapCache memory cache;
        _prepareSwapCache(zeroForIn, swapPool, cache);
        (sqrtPriceX96After, , amountOut) = _simulateSwap(true, amountIn.toInt256(), cache);
    }

    function quoteExactOutputSingle(
        bool zeroForIn,
        address swapPool,
        uint256 amountOut
    ) external view returns (uint160 sqrtPriceX96After, uint256 amountIn) {
        SwapCache memory cache;
        _prepareSwapCache(zeroForIn, swapPool, cache);
        uint256 out;
        (sqrtPriceX96After, amountIn, out) = _simulateSwap(false, -amountOut.toInt256(), cache);
        require(out == amountOut, "LtQV3:IL");
    }

    function getBalanceOf(address token, address target) internal view returns (uint256 balance) {
        bytes memory callData = abi.encodeWithSelector(IERC20.balanceOf.selector, target);
        (bool success, bytes memory data) = token.staticcall(callData);
        require(success && data.length >= 32);
        balance = abi.decode(data, (uint256));
    }

    function calculateExactZapIn(
        CalculateExactZapInParams memory params
    ) external view returns (uint256 swapAmountIn, uint256 calcAmountIn, uint256 calcAmountOut) {
        uint160 sqrtPriceX96After;
        uint160 sqrtRatioAX96 = TickMath.getSqrtRatioAtTick(params.tickLower);
        uint160 sqrtRatioBX96 = TickMath.getSqrtRatioAtTick(params.tickUpper);
        SwapCache memory cache;
        _prepareSwapCache(params.zeroForIn, params.swapPool, cache);

        (calcAmountIn, calcAmountOut) = _calculateAmounts(
            params.zeroForIn,
            params.liquidityExactAmount,
            cache.sqrtPriceX96,
            sqrtRatioAX96,
            sqrtRatioBX96
        );
        uint256 amountInNext = params.tokenInBalance - calcAmountIn;

        if (params.tokenOutBalance < calcAmountOut) {
            require(amountInNext > 0, "LtQV3:IB");
            uint256 amountOut;
            uint256 amountIn;
            (sqrtPriceX96After, amountIn, amountOut) = _simulateSwap(
                false,
                -calcAmountOut.toInt256(),
                cache
            );

            if (amountIn > amountInNext) {
                amountIn = amountInNext;
            }
            for (uint256 i; i < MAX_ITER; ) {
                (sqrtPriceX96After, amountIn, amountOut) = _simulateSwap(
                    true,
                    amountIn.toInt256(),
                    cache
                );

                (calcAmountIn, calcAmountOut) = _calculateAmounts(
                    params.zeroForIn,
                    params.liquidityExactAmount,
                    sqrtPriceX96After,
                    sqrtRatioAX96,
                    sqrtRatioBX96
                );

                if (calcAmountOut == 0 || calcAmountIn > params.tokenInBalance - amountIn) {
                    amountInNext = (amountIn * 900) / 1000;
                } else {
                    (, amountInNext, ) = _simulateSwap(false, -calcAmountOut.toInt256(), cache);
                }

                if (
                    amountIn > 0 &&
                    amountOut + params.tokenOutBalance >= calcAmountOut &&
                    calcAmountIn <= params.tokenInBalance - amountIn
                ) {
                    swapAmountIn = amountIn;
                    break;
                }

                amountIn = amountInNext;

                unchecked {
                    ++i;
                }
            }
            if (swapAmountIn == 0) {
                (calcAmountIn, calcAmountOut) = _calculateAmounts(
                    params.zeroForIn,
                    params.liquidityExactAmount,
                    cache.sqrtPriceX96,
                    sqrtRatioAX96,
                    sqrtRatioBX96
                );
                amountInNext = params.tokenInBalance - calcAmountIn;
                revert LtQV3ZapInFailed(
                    amountInNext,
                    calcAmountIn,
                    calcAmountOut,
                    params.tokenInBalance,
                    params.tokenOutBalance
                );
            }
        }
        // returns as token0, token1
        if (!params.zeroForIn) {
            (calcAmountIn, calcAmountOut) = (calcAmountOut, calcAmountIn);
        }
    }

    function _calculateAmounts(
        bool zeroForIn,
        uint128 liquidityExactAmount,
        uint160 sqrtPriceX96,
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96
    ) private pure returns (uint256 calcAmountIn, uint256 calcAmountOut) {
        (uint256 amount0, uint256 amount1) = AmountsLiquidity.getAmountsRoundingUpForLiquidity(
            sqrtPriceX96,
            sqrtRatioAX96,
            sqrtRatioBX96,
            liquidityExactAmount
        );

        (calcAmountIn, calcAmountOut) = zeroForIn ? (amount0, amount1) : (amount1, amount0);
    }

    function _prepareSwapCache(
        bool zeroForOne,
        address swapPool,
        SwapCache memory cache
    ) private view {
        (uint160 sqrtPriceX96, int24 tick, , , , uint8 feeProtocol, ) = IUniswapV3Pool(swapPool)
            .slot0();
        cache.zeroForOne = zeroForOne;
        cache.liquidityStart = IUniswapV3Pool(swapPool).liquidity();
        cache.feeProtocol = zeroForOne ? (feeProtocol % 16) : (feeProtocol >> 4);
        cache.fee = IUniswapV3Pool(swapPool).fee();
        cache.tickSpacing = IUniswapV3Pool(swapPool).tickSpacing();
        cache.tick = tick;
        cache.sqrtPriceX96 = sqrtPriceX96;
        cache.sqrtPriceX96Limit = zeroForOne
            ? TickMath.MIN_SQRT_RATIO + 1
            : TickMath.MAX_SQRT_RATIO - 1;
        cache.swapPool = swapPool;
    }

    function _simulateSwap(
        bool exactInput,
        int256 amountSpecified,
        SwapCache memory cache
    ) private view returns (uint160, uint256, uint256) {
        require(amountSpecified != 0, "LtQV3:AS");
        SwapState memory state = SwapState({
            amountSpecifiedRemaining: amountSpecified,
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

        unchecked {
            return
                exactInput
                    ? (
                        state.sqrtPriceX96,
                        uint256(amountSpecified - state.amountSpecifiedRemaining),
                        uint256(-state.amountCalculated)
                    )
                    : (
                        state.sqrtPriceX96,
                        uint256(state.amountCalculated),
                        uint256(-(amountSpecified - state.amountSpecifiedRemaining))
                    );
        }
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
