// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.23;

import { IUniswapV3Pool } from "./interfaces/IUniswapV3Pool.sol";
import { TickMath } from "./vendor0.8/uniswap/TickMath.sol";
import { AmountsLiquidity } from "./libraries/AmountsLiquidity.sol";
import { FullMath, LiquidityAmounts } from "./vendor0.8/uniswap/LiquidityAmounts.sol";
import "./interfaces/INonfungiblePositionManager.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

// import "hardhat/console.sol";

contract PositionEffectivityChart {
    struct LoanInfo {
        uint128 liquidity;
        uint256 tokenId;
    }
    struct Chart {
        uint256 x; //price
        int256 y; //profit
    }

    /// @notice Describes a loan's position data for charting purposes
    struct LoansData {
        uint256 amount; // The amount of the holdToken debt
        uint256 minPrice; // The minimum price based on lowerSqrtPriceX96
        uint256 maxPrice; // The maximum price based on upperSqrtPriceX96
    }

    struct CalcCashe {
        uint160 maxSqrtPriceX96;
        uint160 minSqrtPriceX96;
        uint256 holdTokenDebtSum;
        uint256 marginDepoSum;
    }

    struct NftPositionCache {
        uint24 fee;
        uint160 lowerSqrtPriceX96;
        uint160 upperSqrtPriceX96;
        int24 entryTick;
        uint160 entrySqrtPriceX96;
        address saleToken;
        address holdToken;
        uint256 holdTokenDebt;
        uint256 marginDepo;
    }
    /// @dev The minimum value that can be returned from #getSqrtRatioAtTick. Equivalent to getSqrtRatioAtTick(MIN_TICK)
    uint160 internal constant MIN_SQRT_RATIO = 4295128739;

    /// @dev The maximum value that can be returned from #getSqrtRatioAtTick. Equivalent to getSqrtRatioAtTick(MAX_TICK)
    uint160 internal constant MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970342;

    address public immutable UNDERLYING_V3_FACTORY_ADDRESS;
    address public immutable UNDERLYING_POSITION_MANAGER_ADDRESS;
    bytes32 public immutable UNDERLYING_V3_POOL_INIT_CODE_HASH;

    constructor(
        address _positionManagerAddress,
        address _v3FactoryAddress,
        bytes32 _v3PoolInitCodeHash
    ) {
        UNDERLYING_V3_FACTORY_ADDRESS = _v3FactoryAddress;
        UNDERLYING_V3_POOL_INIT_CODE_HASH = _v3PoolInitCodeHash;
        UNDERLYING_POSITION_MANAGER_ADDRESS = _positionManagerAddress;
    }

    function _calcMargin(
        uint160 step,
        uint160 maxSqrtPriceX96,
        uint160 minSqrtPriceX96,
        uint160 marginPointsNumber
    ) private pure returns (uint160 margin, uint256 pointsNumber) {
        uint160 maxMarginPoints = (maxSqrtPriceX96 - minSqrtPriceX96) / step;
        if (maxMarginPoints < marginPointsNumber) {
            margin = step * maxMarginPoints;
            pointsNumber = maxMarginPoints;
        } else {
            margin = step * marginPointsNumber;
            pointsNumber = marginPointsNumber;
        }
    }

    /// @notice Creates charts representing loan positions over a price range, including an aggressive mode profit line.
    /// @param zeroForSaleToken Flag indicating whether the sale token is zero for price calculations
    /// @param loans Array of loan positions that will be visualized
    /// @param pointsNumber Number of points to plot on the chart for the price range
    /// @param marginPointsNumber Number of additional margin points for the price range on the chart
    /// @return loansChartData An array with detailed information for each loan position
    /// @return aggressiveModeProfitLine A two-point line showing potential profit in an aggressive margin setup
    /// @return chart An array of Chart structs representing the loan positions over the plotted price range
    function createChart(
        bool zeroForSaleToken,
        LoanInfo[] calldata loans,
        uint256 pointsNumber,
        uint160 marginPointsNumber
    )
        external
        view
        returns (
            LoansData[] memory loansChartData,
            Chart[2] memory aggressiveModeProfitLine,
            Chart[] memory chart
        )
    {
        if (pointsNumber < 6) {
            pointsNumber = 6;
        }
        NftPositionCache[] memory caches = new NftPositionCache[](loans.length);
        loansChartData = new LoansData[](loans.length);
        CalcCashe memory calcCashe;
        uint128 oneHoldToken;
        uint256 weightedAverageEntraceSqrtPriceX96;
        {
            calcCashe.minSqrtPriceX96 = MAX_SQRT_RATIO;
            calcCashe.maxSqrtPriceX96 = MIN_SQRT_RATIO;

            for (uint256 i = 0; i < loans.length; ) {
                _upNftPositionCache(zeroForSaleToken, loans[i], caches[i]);

                if (i == 0) {
                    oneHoldToken = uint128(10 ** IERC20Metadata(caches[0].holdToken).decimals());
                }

                if (caches[i].lowerSqrtPriceX96 < calcCashe.minSqrtPriceX96) {
                    calcCashe.minSqrtPriceX96 = caches[i].lowerSqrtPriceX96;
                }

                if (caches[i].upperSqrtPriceX96 > calcCashe.maxSqrtPriceX96) {
                    calcCashe.maxSqrtPriceX96 = caches[i].upperSqrtPriceX96;
                }

                if (caches[i].entrySqrtPriceX96 < calcCashe.minSqrtPriceX96) {
                    calcCashe.minSqrtPriceX96 = caches[i].entrySqrtPriceX96;
                }

                if (caches[i].entrySqrtPriceX96 > calcCashe.maxSqrtPriceX96) {
                    calcCashe.maxSqrtPriceX96 = caches[i].entrySqrtPriceX96;
                }
                calcCashe.holdTokenDebtSum += caches[i].holdTokenDebt;
                calcCashe.marginDepoSum += caches[i].marginDepo;

                weightedAverageEntraceSqrtPriceX96 += FullMath.mulDiv(
                    caches[i].entrySqrtPriceX96,
                    caches[i].holdTokenDebt,
                    1 << 64
                );

                loansChartData[i].amount = caches[i].holdTokenDebt;
                loansChartData[i].minPrice = _getAmountOut(
                    !zeroForSaleToken,
                    caches[i].lowerSqrtPriceX96,
                    oneHoldToken
                );

                loansChartData[i].maxPrice = _getAmountOut(
                    !zeroForSaleToken,
                    caches[i].upperSqrtPriceX96,
                    oneHoldToken
                );
                unchecked {
                    ++i;
                }
            }
            weightedAverageEntraceSqrtPriceX96 = FullMath.mulDiv(
                weightedAverageEntraceSqrtPriceX96,
                1 << 64,
                calcCashe.holdTokenDebtSum
            );
        }

        uint160 step = uint160(
            (calcCashe.maxSqrtPriceX96 - calcCashe.minSqrtPriceX96) / pointsNumber
        );
        require(step > 0, "step is 0");
        {
            (uint160 margin, uint256 maxMarginPoints) = _calcMargin(
                step,
                calcCashe.minSqrtPriceX96, //max
                MIN_SQRT_RATIO, //min
                marginPointsNumber
            );
            calcCashe.minSqrtPriceX96 -= margin;
            pointsNumber += maxMarginPoints;

            (margin, maxMarginPoints) = _calcMargin(
                step,
                MAX_SQRT_RATIO, //max
                calcCashe.maxSqrtPriceX96, //min
                marginPointsNumber
            );
            calcCashe.maxSqrtPriceX96 += margin;
            pointsNumber += maxMarginPoints;
        }

        chart = new Chart[](pointsNumber);
        uint160 sqrtPriceX96;
        for (uint256 i = 0; i < pointsNumber; ) {
            sqrtPriceX96 = uint160(
                zeroForSaleToken
                    ? (calcCashe.maxSqrtPriceX96 - step * i)
                    : (calcCashe.minSqrtPriceX96 + step * i)
            );

            chart[i].x = _getAmountOut(!zeroForSaleToken, sqrtPriceX96, oneHoldToken);

            for (uint256 j = 0; j < loans.length; ) {
                uint256 holdTokenAmount = _optimisticHoldTokenAmountForLiquidity(
                    zeroForSaleToken,
                    sqrtPriceX96,
                    caches[j].lowerSqrtPriceX96,
                    caches[j].upperSqrtPriceX96,
                    loans[j].liquidity,
                    caches[j].holdTokenDebt
                );

                chart[i].y += int256(holdTokenAmount) - int256(caches[j].marginDepo);

                unchecked {
                    ++j;
                }
            }
            unchecked {
                ++i;
            }
        }

        aggressiveModeProfitLine[0].x = _getAmountOut(
            !zeroForSaleToken,
            uint160(weightedAverageEntraceSqrtPriceX96),
            oneHoldToken
        );
        aggressiveModeProfitLine[1].x = chart[pointsNumber - 1].x;
        uint256 profitInSallToken = ((calcCashe.holdTokenDebtSum * aggressiveModeProfitLine[1].x) -
            ((calcCashe.holdTokenDebtSum - calcCashe.marginDepoSum) *
                aggressiveModeProfitLine[0].x)) / oneHoldToken;

        aggressiveModeProfitLine[1].y =
            int256(_getAmountOut(zeroForSaleToken, sqrtPriceX96, uint128(profitInSallToken))) -
            int256(calcCashe.marginDepoSum);
    }

    function _optimisticHoldTokenAmountForLiquidity(
        bool zeroForSaleToken,
        uint160 sqrtPriceX96,
        uint160 lowerSqrtPriceX96,
        uint160 upperSqrtPriceX96,
        uint128 liquidity,
        uint256 holdTokenDebt
    ) private pure returns (uint256 holdTokenAmount) {
        (uint256 amount0, uint256 amount1) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtPriceX96,
            lowerSqrtPriceX96,
            upperSqrtPriceX96,
            liquidity
        );
        if (!zeroForSaleToken) {
            (amount0, amount1) = (amount1, amount0);
        }
        holdTokenAmount = amount1 + _getAmountOut(zeroForSaleToken, sqrtPriceX96, uint128(amount0));
        holdTokenAmount = holdTokenDebt > holdTokenAmount ? holdTokenDebt - holdTokenAmount : 0;
    }

    function _getAmountOut(
        bool zeroForIn,
        uint160 sqrtPriceX96,
        uint128 amountIn
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

    function _upNftPositionCache(
        bool zeroForSaleToken,
        LoanInfo memory loan,
        NftPositionCache memory cache
    ) internal view {
        int24 tickLower;
        int24 tickUpper;
        // Get the positions data from `PositionManager` and store it in the cache variables
        (
            ,
            ,
            cache.saleToken,
            cache.holdToken,
            cache.fee,
            tickLower,
            tickUpper,
            ,
            ,
            ,
            ,

        ) = INonfungiblePositionManager(UNDERLYING_POSITION_MANAGER_ADDRESS).positions(
            loan.tokenId
        );
        {
            address poolAddress = computePoolAddress(cache.saleToken, cache.holdToken, cache.fee);
            (cache.entrySqrtPriceX96, cache.entryTick, , , , , ) = IUniswapV3Pool(poolAddress)
                .slot0();

            cache.lowerSqrtPriceX96 = TickMath.getSqrtRatioAtTick(tickLower);
            cache.upperSqrtPriceX96 = TickMath.getSqrtRatioAtTick(tickUpper);

            cache.holdTokenDebt = _getSingleSideRoundUpAmount(
                zeroForSaleToken,
                cache.lowerSqrtPriceX96,
                cache.upperSqrtPriceX96,
                loan.liquidity
            );
        }
        if (!zeroForSaleToken) {
            // Swap saleToken and holdToken if zeroForSaleToken is false
            (cache.saleToken, cache.holdToken) = (cache.holdToken, cache.saleToken);
        }

        cache.marginDepo = _optimisticHoldTokenAmountForLiquidity(
            zeroForSaleToken,
            cache.entrySqrtPriceX96,
            cache.lowerSqrtPriceX96,
            cache.upperSqrtPriceX96,
            loan.liquidity,
            cache.holdTokenDebt
        );
    }

    function _getSingleSideRoundUpAmount(
        bool zeroForSaleToken,
        uint160 lowerSqrtPriceX96,
        uint160 upperSqrtPriceX96,
        uint128 liquidity
    ) private pure returns (uint256 amount) {
        amount = (
            zeroForSaleToken
                ? AmountsLiquidity.getAmount1RoundingUpForLiquidity(
                    lowerSqrtPriceX96,
                    upperSqrtPriceX96,
                    liquidity
                )
                : AmountsLiquidity.getAmount0RoundingUpForLiquidity(
                    lowerSqrtPriceX96,
                    upperSqrtPriceX96,
                    liquidity
                )
        );
    }

    function computePoolAddress(
        address tokenA,
        address tokenB,
        uint24 fee
    ) public view returns (address pool) {
        if (tokenA > tokenB) (tokenA, tokenB) = (tokenB, tokenA);
        pool = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex"ff",
                            UNDERLYING_V3_FACTORY_ADDRESS,
                            keccak256(abi.encode(tokenA, tokenB, fee)),
                            UNDERLYING_V3_POOL_INIT_CODE_HASH
                        )
                    )
                )
            )
        );
    }
}
