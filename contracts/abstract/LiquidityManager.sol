// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;
import "../vendor0.8/uniswap/LiquidityAmounts.sol";
import "../vendor0.8/uniswap/TickMath.sol";
import "../interfaces/INonfungiblePositionManager.sol";
import "../interfaces/IQuoterV2.sol";
import "./ApproveSwapAndPay.sol";
import "../Vault.sol";
import { Constants } from "../libraries/Constants.sol";
import { ErrLib } from "../libraries/ErrLib.sol";

abstract contract LiquidityManager is ApproveSwapAndPay {
    using { ErrLib.revertError } for bool;
    /**
     * @notice Represents information about a loan.
     * @dev This struct is used to store liquidity and tokenId for a loan.
     * @param liquidity The amount of liquidity for the loan represented by a uint128 value.
     * @param tokenId The token ID associated with the loan represented by a uint256 value.
     */
    struct LoanInfo {
        uint128 liquidity;
        uint256 tokenId;
    }

    struct Amounts {
        uint256 amount0;
        uint256 amount1;
    }
    /**
     * @notice Contains parameters for restoring liquidity.
     * @dev This struct is used to store various parameters required for restoring liquidity.
     * @param zeroForSaleToken A boolean value indicating whether the token for sale is the 0th token or not.
     * @param fee The fee associated with the internal swap pool is represented by a uint24 value.
     * @param slippageBP1000 The slippage in basis points (BP) represented by a uint256 value.
     * @param totalfeesOwed The total fees owed represented by a uint256 value.
     * @param totalBorrowedAmount The total borrowed amount represented by a uint256 value.
     */
    struct RestoreLiquidityParams {
        bool zeroForSaleToken;
        uint24 fee;
        uint160 sqrtPriceLimitX96;
        uint256 totalfeesOwed;
        uint256 totalBorrowedAmount;
    }
    /**
     * @notice Contains cache data for restoring liquidity.
     * @dev This struct is used to store cached values required for restoring liquidity.
     * @param tickLower The lower tick boundary represented by an int24 value.
     * @param tickUpper The upper tick boundary represented by an int24 value.
     * @param fee The fee associated with the restoring liquidity pool.
     * @param saleToken The address of the token being sold.
     * @param holdToken The address of the token being held.
     * @param sqrtPriceX96 The square root of the price represented by a uint160 value.
     * @param holdTokenDebt The debt amount associated with the hold token represented by a uint256 value.
     */
    struct RestoreLiquidityCache {
        int24 tickLower;
        int24 tickUpper;
        uint24 fee;
        address saleToken;
        address holdToken;
        uint160 sqrtPriceX96;
        uint256 holdTokenDebt;
    }
    /**
     * @notice The address of the vault contract.
     */
    address public immutable VAULT_ADDRESS;
    /**
     * @notice The Nonfungible Position Manager contract.
     */
    INonfungiblePositionManager public immutable underlyingPositionManager;
    /**
     * @notice The QuoterV2 contract.
     */
    IQuoterV2 public immutable underlyingQuoterV2;

    ///  msg.sender => token => FeesAmt
    mapping(address => mapping(address => uint256)) internal loansFeesInfo;

    /**
     * @dev Contract constructor.
     * @param _underlyingPositionManagerAddress Address of the underlying position manager contract.
     * @param _underlyingQuoterV2 Address of the underlying quoterV2 contract.
     * @param _underlyingV3Factory Address of the underlying V3 factory contract.
     * @param _underlyingV3PoolInitCodeHash The init code hash of the underlying V3 pool.
     */
    constructor(
        address _underlyingPositionManagerAddress,
        address _underlyingQuoterV2,
        address _underlyingV3Factory,
        bytes32 _underlyingV3PoolInitCodeHash
    ) ApproveSwapAndPay(_underlyingV3Factory, _underlyingV3PoolInitCodeHash) {
        // Assign the underlying position manager contract address
        underlyingPositionManager = INonfungiblePositionManager(_underlyingPositionManagerAddress);
        // Assign the underlying quoterV2 contract address
        underlyingQuoterV2 = IQuoterV2(_underlyingQuoterV2);
        // Generate a unique salt for the new Vault contract
        bytes32 salt = keccak256(abi.encode(block.timestamp, address(this)));
        // Deploy a new Vault contract using the generated salt and assign its address to VAULT_ADDRESS
        VAULT_ADDRESS = address(new Vault{ salt: salt }());
    }

    error InvalidBorrowedLiquidityAmount(
        uint256 tokenId,
        uint128 posLiquidity,
        uint128 minLiquidityAmt,
        uint128 liquidity
    );
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

    /**
     * @dev Calculates the borrowed amount from a pool's single side position, rounding up if necessary.
     * @param zeroForSaleToken A boolean value indicating whether the token for sale is the 0th token or not.
     * @param tickLower The lower tick value of the position range.
     * @param tickUpper The upper tick value of the position range.
     * @param liquidity The liquidity of the position.
     * @return borrowedAmount The calculated borrowed amount.
     */
    function _getSingleSideRoundUpBorrowedAmount(
        bool zeroForSaleToken,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity
    ) private pure returns (uint256 borrowedAmount) {
        borrowedAmount = (
            zeroForSaleToken
                ? LiquidityAmounts.getAmount1RoundingUpForLiquidity(
                    TickMath.getSqrtRatioAtTick(tickLower),
                    TickMath.getSqrtRatioAtTick(tickUpper),
                    liquidity
                )
                : LiquidityAmounts.getAmount0RoundingUpForLiquidity(
                    TickMath.getSqrtRatioAtTick(tickLower),
                    TickMath.getSqrtRatioAtTick(tickUpper),
                    liquidity
                )
        );
    }

    /**
     * @dev Calculates the minimum liquidity amount for a given tick range.
     * @param tickLower The lower tick of the range.
     * @param tickUpper The upper tick of the range.
     * @return minLiquidity The minimum liquidity amount.
     */
    function _getMinLiquidityAmt(
        int24 tickLower,
        int24 tickUpper
    ) internal pure returns (uint128 minLiquidity) {
        uint128 liquidity0 = LiquidityAmounts.getLiquidityForAmount0(
            TickMath.getSqrtRatioAtTick(tickUpper - 1),
            TickMath.getSqrtRatioAtTick(tickUpper),
            Constants.MINIMUM_EXTRACTED_AMOUNT
        );
        uint128 liquidity1 = LiquidityAmounts.getLiquidityForAmount1(
            TickMath.getSqrtRatioAtTick(tickLower),
            TickMath.getSqrtRatioAtTick(tickLower + 1),
            Constants.MINIMUM_EXTRACTED_AMOUNT
        );
        minLiquidity = liquidity0 > liquidity1 ? liquidity0 : liquidity1;
    }

    /**
     * @dev Extracts liquidity from loans and returns the borrowed amount.
     * @param zeroForSaleToken A boolean value indicating whether the token for sale is the 0th token or not.
     * @param token0 The address of one of the tokens in the pair.
     * @param token1 The address of the other token in the pair.
     * @param loans An array of LoanInfo struct instances containing loan information.
     * @return borrowedAmount The total amount borrowed.
     */
    function _extractLiquidity(
        bool zeroForSaleToken,
        address token0,
        address token1,
        LoanInfo[] memory loans
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
                uint128 minLiquidityAmt = _getMinLiquidityAmt(tickLower, tickUpper);
                if (liquidity > posLiquidity || liquidity < minLiquidityAmt) {
                    revert InvalidBorrowedLiquidityAmount(
                        tokenId,
                        posLiquidity,
                        minLiquidityAmt,
                        liquidity
                    );
                }

                // Calculate borrowed amount
                borrowedAmount += _getSingleSideRoundUpBorrowedAmount(
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
     * @dev This function is used to simulate a swap operation.
     *
     * It quotes the exact input single for the swap using the `underlyingQuoterV2` contract.
     *
     * @param fee The pool's fee in hundredths of a bip, i.e. 1e-6
     * @param tokenIn The address of the token being used as input for the swap.
     * @param tokenOut The address of the token being received as output from the swap.
     * @param amountIn The amount of tokenIn to be used as input for the swap.
     *
     * @return sqrtPriceX96After The square root price after the swap.
     * @return amountOut The amount of tokenOut received as output from the swap.
     */
    function _simulateSwap(
        uint24 fee,
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) private returns (uint160 sqrtPriceX96After, uint256 amountOut) {
        // Quote exact input single for swap
        (amountOut, sqrtPriceX96After, , ) = underlyingQuoterV2.quoteExactInputSingle(
            IQuoterV2.QuoteExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                amountIn: amountIn,
                fee: fee,
                sqrtPriceLimitX96: 0
            })
        );
    }

    /**
     * @dev This function is used to prevent front-running during a swap.
     *
     * We do not check slippage during a swap as we need to restore liquidity anyway despite the losses,
     * so we only check the initial price state in the pool to prevent price manipulation.
     *
     * When liquidity is restored, a hold token is sold therefore,
     * - If `zeroForSaleToken` is `false`, the current `sqrtPrice` cannot be less than `sqrtPriceLimitX96`.
     * - If `zeroForSaleToken` is `true`, the current `sqrtPrice` cannot be greater than `sqrtPriceLimitX96`.
     *
     * @param zeroForSaleToken A boolean indicating whether the sale token is zero or not.
     * @param fee The fee for the swap.
     * @param sqrtPriceLimitX96 The square root price limit for the swap.
     * @param saleToken The address of the token being sold.
     * @param holdToken The address of the token being held.
     */
    function _frontRunningAttackPrevent(
        bool zeroForSaleToken,
        uint24 fee,
        uint160 sqrtPriceLimitX96,
        address saleToken,
        address holdToken
    ) internal view {
        uint160 sqrtPriceX96 = _getCurrentSqrtPriceX96(zeroForSaleToken, saleToken, holdToken, fee);
        (zeroForSaleToken ? sqrtPriceX96 > sqrtPriceLimitX96 : sqrtPriceX96 < sqrtPriceLimitX96)
            .revertError(ErrLib.ErrorCode.UNACCEPTABLE_SQRT_PRICE);
    }

    /**
     * @dev Restores liquidity from loans.
     * @param params The RestoreLiquidityParams struct containing restoration parameters.
     * @param externalSwap The SwapParams struct containing external swap details.
     * @param loans An array of LoanInfo struct instances containing loan information.
     */
    function _restoreLiquidity(
        // Create a cache struct to store temporary data
        RestoreLiquidityParams memory params,
        SwapParams calldata externalSwap,
        LoanInfo[] memory loans
    ) internal {
        RestoreLiquidityCache memory cache;
        for (uint256 i; i < loans.length; ) {
            // Update the cache for the current loan
            LoanInfo memory loan = loans[i];
            // Get the owner of the Nonfungible Position Manager token by its tokenId
            address creditor = _getOwnerOf(loan.tokenId);
            // Check that the token is not burned
            if (creditor != address(0)) {
                _upRestoreLiquidityCache(params.zeroForSaleToken, loan, cache);
                // Calculate the hold token amount to be used for swapping
                (uint256 holdTokenAmountIn, Amounts memory amounts) = _getHoldTokenAmountIn(
                    params.zeroForSaleToken,
                    cache.tickLower,
                    cache.tickUpper,
                    cache.sqrtPriceX96,
                    loan.liquidity,
                    cache.holdTokenDebt
                );

                if (holdTokenAmountIn > 0) {
                    if (params.sqrtPriceLimitX96 != 0) {
                        _frontRunningAttackPrevent(
                            params.zeroForSaleToken,
                            params.fee,
                            params.sqrtPriceLimitX96,
                            cache.saleToken,
                            cache.holdToken
                        );
                    }
                    // Perform external swap if external swap target is provided
                    if (externalSwap.swapTarget != address(0)) {
                        uint256 saleTokenAmountOut;
                        if (params.sqrtPriceLimitX96 != 0) {
                            (, saleTokenAmountOut) = _simulateSwap(
                                params.fee,
                                cache.holdToken,
                                cache.saleToken,
                                holdTokenAmountIn
                            );
                        }
                        _patchAmountsAndCallSwap(
                            cache.holdToken,
                            cache.saleToken,
                            externalSwap,
                            holdTokenAmountIn,
                            // The minimum amount out should not be less than with an internal pool swap.
                            // checking only once during the first swap when params.sqrtPriceLimitX96 != 0
                            saleTokenAmountOut
                        );
                    } else {
                        //  The internal swap in the same pool in which liquidity is restored.
                        if (params.fee == cache.fee) {
                            (cache.sqrtPriceX96, ) = _simulateSwap(
                                params.fee,
                                cache.holdToken,
                                cache.saleToken,
                                holdTokenAmountIn
                            );

                            // recalculate the hold token amount again for the new sqrtPriceX96
                            (holdTokenAmountIn, ) = _getHoldTokenAmountIn(
                                params.zeroForSaleToken,
                                cache.tickLower,
                                cache.tickUpper,
                                cache.sqrtPriceX96, // updated by IQuoterV2.QuoteExactInputSingleParams
                                loan.liquidity,
                                cache.holdTokenDebt
                            );
                        }

                        // Perform v3 swap exact input and update sqrtPriceX96
                        _v3SwapExactInput(
                            v3SwapExactInputParams({
                                fee: params.fee,
                                tokenIn: cache.holdToken,
                                tokenOut: cache.saleToken,
                                amountIn: holdTokenAmountIn
                            })
                        );
                        // Update the value of sqrtPriceX96 in the cache using the _getCurrentSqrtPriceX96 function
                        cache.sqrtPriceX96 = _getCurrentSqrtPriceX96(
                            params.zeroForSaleToken,
                            cache.saleToken,
                            cache.holdToken,
                            cache.fee
                        );
                        // Calculate the amounts of token0 and token1 for a given liquidity
                        (amounts.amount0, amounts.amount1) = LiquidityAmounts
                            .getAmountsRoundingUpForLiquidity(
                                cache.sqrtPriceX96,
                                TickMath.getSqrtRatioAtTick(cache.tickLower),
                                TickMath.getSqrtRatioAtTick(cache.tickUpper),
                                loan.liquidity
                            );
                    }
                    // the price manipulation check is carried out only once
                    params.sqrtPriceLimitX96 = 0;
                }

                // Increase liquidity and transfer liquidity owner reward
                _increaseLiquidity(
                    cache.saleToken,
                    cache.holdToken,
                    loan,
                    amounts.amount0,
                    amounts.amount1
                );
                uint256 liquidityOwnerReward = FullMath.mulDiv(
                    params.totalfeesOwed,
                    cache.holdTokenDebt,
                    params.totalBorrowedAmount
                );

                loansFeesInfo[creditor][cache.holdToken] += liquidityOwnerReward;
            }

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev Retrieves the owner of a token without causing a revert if token not exist.
     * @param tokenId The identifier of the token.
     * @return tokenOwner The address of the token owner.
     */
    function _getOwnerOf(uint256 tokenId) internal view returns (address tokenOwner) {
        bytes memory callData = abi.encodeWithSelector(
            underlyingPositionManager.ownerOf.selector,
            tokenId
        );
        (bool success, bytes memory data) = address(underlyingPositionManager).staticcall(callData);
        if (success && data.length >= 32) {
            tokenOwner = abi.decode(data, (address));
        }
    }

    /**
     * @dev Retrieves the current square root price in X96 representation.
     * @param zeroForA Flag indicating whether to treat the tokenA as the 0th token or not.
     * @param tokenA The address of token A.
     * @param tokenB The address of token B.
     * @param fee The fee associated with the Uniswap V3 pool.
     * @return sqrtPriceX96 The current square root price in X96 representation.
     */
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

    /**
     * @dev Decreases the liquidity of a position by removing tokens.
     * @param tokenId The ID of the position token.
     * @param liquidity The amount of liquidity to be removed.
     */
    function _decreaseLiquidity(uint256 tokenId, uint128 liquidity) private {
        // Call the decreaseLiquidity function of underlyingPositionManager contract
        // with DecreaseLiquidityParams struct as argument
        (uint256 amount0, uint256 amount1) = underlyingPositionManager.decreaseLiquidity(
            INonfungiblePositionManager.DecreaseLiquidityParams({
                tokenId: tokenId,
                liquidity: liquidity,
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp
            })
        );
        // Call the collect function of underlyingPositionManager contract
        // with CollectParams struct as argument
        (amount0, amount1) = underlyingPositionManager.collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: tokenId,
                recipient: address(this),
                amount0Max: uint128(amount0),
                amount1Max: uint128(amount1)
            })
        );
    }

    /**
     * @dev Increases the liquidity of a position by providing additional tokens.
     * @param saleToken The address of the sale token.
     * @param holdToken The address of the hold token.
     * @param loan An instance of LoanInfo memory struct containing loan details.
     * @param amount0 The amount of token0 to be added to the liquidity.
     * @param amount1 The amount of token1 to be added to the liquidity.
     */
    function _increaseLiquidity(
        address saleToken,
        address holdToken,
        LoanInfo memory loan,
        uint256 amount0,
        uint256 amount1
    ) private {
        // Call the increaseLiquidity function of underlyingPositionManager contract
        // with IncreaseLiquidityParams struct as argument
        (uint128 restoredLiquidity, , ) = underlyingPositionManager.increaseLiquidity(
            INonfungiblePositionManager.IncreaseLiquidityParams({
                tokenId: loan.tokenId,
                amount0Desired: amount0,
                amount1Desired: amount1,
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp
            })
        );
        // Check if the restored liquidity is less than the loan liquidity amount
        // If true, revert with InvalidRestoredLiquidity exception
        if (restoredLiquidity < loan.liquidity) {
            // Get the balance of holdToken and saleToken
            (uint256 holdTokentBalance, uint256 saleTokenBalance) = _getPairBalance(
                holdToken,
                saleToken
            );

            revert InvalidRestoredLiquidity(
                loan.tokenId,
                loan.liquidity,
                restoredLiquidity,
                amount0,
                amount1,
                holdTokentBalance,
                saleTokenBalance
            );
        }
    }

    /**
     * @dev Calculates the amount of hold token required for a swap.
     * @param zeroForSaleToken A boolean value indicating whether the token for sale is the 0th token or not.
     * @param tickLower The lower tick of the liquidity range.
     * @param tickUpper The upper tick of the liquidity range.
     * @param sqrtPriceX96 The square root of the price ratio of the sale token to the hold token.
     * @param liquidity The amount of liquidity.
     * @param holdTokenDebt The amount of hold token debt.
     * @return holdTokenAmountIn The amount of hold token needed to provide the specified liquidity.
     * @return amounts The amounts of token0 and token1 calculated based on the liquidity.
     */
    function _getHoldTokenAmountIn(
        bool zeroForSaleToken,
        int24 tickLower,
        int24 tickUpper,
        uint160 sqrtPriceX96,
        uint128 liquidity,
        uint256 holdTokenDebt
    ) private pure returns (uint256 holdTokenAmountIn, Amounts memory amounts) {
        // Call getAmountsForLiquidity function from LiquidityAmounts library
        // to get the amounts of token0 and token1 for a given liquidity position
        (amounts.amount0, amounts.amount1) = LiquidityAmounts.getAmountsRoundingUpForLiquidity(
            sqrtPriceX96,
            TickMath.getSqrtRatioAtTick(tickLower),
            TickMath.getSqrtRatioAtTick(tickUpper),
            liquidity
        );
        // Calculate the holdTokenAmountIn based on the zeroForSaleToken flag
        holdTokenAmountIn = zeroForSaleToken
            ? holdTokenDebt - amounts.amount1
            : holdTokenDebt - amounts.amount0;
    }

    /**
     * @dev Updates the RestoreLiquidityCache struct with data from the underlyingPositionManager contract.
     * @param zeroForSaleToken A boolean value indicating whether the token for sale is the 0th token or not.
     * @param loan The LoanInfo struct containing loan details.
     * @param cache The RestoreLiquidityCache struct to be updated.
     */
    function _upRestoreLiquidityCache(
        bool zeroForSaleToken,
        LoanInfo memory loan,
        RestoreLiquidityCache memory cache
    ) internal view {
        // Get the positions data from `PositionManager` and store it in the cache variables
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

        ) = underlyingPositionManager.positions(loan.tokenId);
        // Swap saleToken and holdToken if zeroForSaleToken is false
        if (!zeroForSaleToken) {
            (cache.saleToken, cache.holdToken) = (cache.holdToken, cache.saleToken);
        }
        // Calculate the holdTokenDebt using
        cache.holdTokenDebt = _getSingleSideRoundUpBorrowedAmount(
            zeroForSaleToken,
            cache.tickLower,
            cache.tickUpper,
            loan.liquidity
        );
        // Calculate the square root price using `_getCurrentSqrtPriceX96` function
        cache.sqrtPriceX96 = _getCurrentSqrtPriceX96(
            zeroForSaleToken,
            cache.saleToken,
            cache.holdToken,
            cache.fee
        );
    }
}
