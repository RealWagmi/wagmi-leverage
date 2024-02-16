// SPDX-License-Identifier: SAL-1.0
pragma solidity 0.8.21;
import "../vendor0.8/uniswap/LiquidityAmounts.sol";
import "../vendor0.8/uniswap/TickMath.sol";
import "./ApproveSwapAndPay.sol";
import "../Vault.sol";
import { Constants } from "../libraries/Constants.sol";
import { ErrLib } from "../libraries/ErrLib.sol";
import { AmountsLiquidity } from "../libraries/AmountsLiquidity.sol";
import "../interfaces/abstract/ILiquidityManager.sol";

// import "hardhat/console.sol";

abstract contract LiquidityManager is ApproveSwapAndPay, ILiquidityManager {
    using { ErrLib.revertError } for bool;

    /**
     * @notice The address of the vault contract.
     */
    address public immutable VAULT_ADDRESS;
    /**
     * @notice The Nonfungible Position Manager contract.
     */
    INonfungiblePositionManager public immutable underlyingPositionManager;
    /**
     * @notice The Quoter contract.
     */
    ILightQuoterV3 public immutable lightQuoterV3;

    ///  msg.sender => token => FeesAmt
    mapping(address => mapping(address => uint256)) internal loansFeesInfo;

    /**
     * @dev Contract constructor.
     * @param _underlyingPositionManagerAddress Address of the underlying position manager contract.
     * @param _lightQuoterV3 Address of the LightQuoterV3 contract.
     * @param _underlyingV3Factory Address of the underlying V3 factory contract.
     * @param _underlyingV3PoolInitCodeHash The init code hash of the underlying V3 pool.
     */
    constructor(
        address _underlyingPositionManagerAddress,
        address _lightQuoterV3,
        address _underlyingV3Factory,
        bytes32 _underlyingV3PoolInitCodeHash
    ) ApproveSwapAndPay(_underlyingV3Factory, _underlyingV3PoolInitCodeHash) {
        // Assign the underlying position manager contract address
        underlyingPositionManager = INonfungiblePositionManager(_underlyingPositionManagerAddress);
        // Assign the quoter contract address
        lightQuoterV3 = ILightQuoterV3(_lightQuoterV3);
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
                ? AmountsLiquidity.getAmount1RoundingUpForLiquidity(
                    TickMath.getSqrtRatioAtTick(tickLower),
                    TickMath.getSqrtRatioAtTick(tickUpper),
                    liquidity
                )
                : AmountsLiquidity.getAmount0RoundingUpForLiquidity(
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
     * @notice This function extracts liquidity from provided loans and calculates the total borrowed amount.
     * @dev Iterates through an array of LoanInfo structs, validates loan parameters, and accumulates borrowed amounts.
     * @param zeroForSaleToken A boolean indicating whether the token for sale is the 0th token in the pair.
     * @param saleToken The address of the token being sold in the trading pair.
     * @param holdToken The address of the token being held in the trading pair.
     * @param loans An array of LoanInfo struct instances, each representing a loan from which to extract liquidity.
     * @return borrowedAmount The total amount of the holdToken that has been borrowed across all provided loans.
     */
    function _extractLiquidity(
        bool zeroForSaleToken,
        address saleToken,
        address holdToken,
        LoanInfo[] memory loans
    ) internal returns (uint256 borrowedAmount) {
        NftPositionCache memory cache;

        for (uint256 i; i < loans.length; ) {
            LoanInfo memory loan = loans[i];
            // Extract position-related details
            _upNftPositionCache(zeroForSaleToken, loan, cache);

            // Check operator approval
            if (cache.operator != address(this)) {
                revert NotApproved(loan.tokenId);
            }
            // Check token validity
            if (cache.saleToken != saleToken || cache.holdToken != holdToken) {
                revert InvalidTokens(loan.tokenId);
            }

            // Check borrowed liquidity validity
            uint128 minLiquidityAmt = _getMinLiquidityAmt(cache.tickLower, cache.tickUpper);
            if (loan.liquidity > cache.liquidity || loan.liquidity < minLiquidityAmt) {
                revert InvalidBorrowedLiquidityAmount(
                    loan.tokenId,
                    cache.liquidity,
                    minLiquidityAmt,
                    loan.liquidity
                );
            }

            // Calculate borrowed amount
            borrowedAmount += cache.holdTokenDebt;
            // Decrease liquidity and move to the next loan
            _decreaseLiquidity(loan.tokenId, loan.liquidity);

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev This function is used to simulate a swap operation.
     *
     * It quotes the exact input single for the swap using the `lightQuoterV3` contract.
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
        bool zeroForIn,
        uint24 fee,
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) internal view returns (uint160 sqrtPriceX96After, uint256 amountOut) {
        // Quote exact input single for swap
        address pool = computePoolAddress(tokenIn, tokenOut, fee);
        (sqrtPriceX96After, amountOut) = lightQuoterV3.quoteExactInputSingle(
            zeroForIn,
            pool,
            0, //sqrtPriceLimitX96
            amountIn
        );
    }

    function _calculateAmountsToSwap(
        bool zeroForIn,
        uint160 currentSqrtPriceX96,
        uint128 liquidity,
        NftPositionCache memory cache,
        uint256 tokenOutBalance
    ) private view returns (uint160 sqrtPriceX96After, uint256 amountIn, Amounts memory amounts) {
        address pool = computePoolAddress(cache.holdToken, cache.saleToken, cache.fee);

        (, sqrtPriceX96After, amountIn, , amounts.amount0, amounts.amount1) = lightQuoterV3
            .calculateExactZapIn(
                ILightQuoterV3.CalculateExactZapInParams({
                    swapPool: pool,
                    zeroForIn: zeroForIn,
                    sqrtPriceX96: currentSqrtPriceX96,
                    tickLower: cache.tickLower,
                    tickUpper: cache.tickUpper,
                    liquidityExactAmount: liquidity,
                    tokenInBalance: cache.holdTokenDebt,
                    tokenOutBalance: tokenOutBalance
                })
            );
    }

    /**
     * @dev Restores liquidity from loans.
     * @param params The RestoreLiquidityParams struct containing restoration parameters.
     * @param loans An array of LoanInfo struct instances containing loan information.
     */
    function _restoreLiquidity(
        RestoreLiquidityParams memory params,
        LoanInfo[] memory loans
    ) internal {
        NftPositionCache memory cache;

        for (uint256 i; i < loans.length; ) {
            // Update the cache for the current loan
            LoanInfo memory loan = loans[i];
            // Get the owner of the Nonfungible Position Manager token by its tokenId
            address creditor = _getOwnerOf(loan.tokenId);
            // Check that the token is not burned
            if (creditor != address(0)) {
                _upNftPositionCache(params.zeroForSaleToken, loan, cache);

                // Calculate the square root price using `_getCurrentSqrtPriceX96` function
                uint160 sqrtPriceX96 = _getCurrentSqrtPriceX96(
                    params.zeroForSaleToken,
                    cache.saleToken,
                    cache.holdToken,
                    cache.fee
                );
                uint256 saleTokenBalance = _getBalance(cache.saleToken);
                // Calculate the hold token amount to be used for swapping
                (uint256 holdTokenAmountIn, Amounts memory amounts) = _getHoldTokenAmountIn(
                    params.zeroForSaleToken,
                    cache.tickLower,
                    cache.tickUpper,
                    sqrtPriceX96,
                    loan.liquidity,
                    cache.holdTokenDebt,
                    saleTokenBalance
                );

                if (holdTokenAmountIn > 0) {
                    //  The internal swap in the same pool in which liquidity is restored.
                    if (params.swapPoolfeeTier == cache.fee) {
                        (sqrtPriceX96, holdTokenAmountIn, amounts) = _calculateAmountsToSwap(
                            !params.zeroForSaleToken,
                            sqrtPriceX96,
                            loan.liquidity,
                            cache,
                            saleTokenBalance
                        );
                    }

                    // Perform v3 swap exact input and update sqrtPriceX96
                    _v3SwapExactInput(
                        v3SwapExactInputParams({
                            fee: params.swapPoolfeeTier,
                            tokenIn: cache.holdToken,
                            tokenOut: cache.saleToken,
                            amountIn: holdTokenAmountIn
                        })
                    );
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
     * @notice Calculates the required hold token amount and expected amounts of token0 and token1 for providing liquidity.
     * @dev This function uses the `AmountsLiquidity` library to determine the token amounts based on provided liquidity parameters.
     * @param zeroForSaleToken Indicates if the sale token is token0 (`true`) or token1 (`false`)
     * @param tickLower The lower tick of the liquidity price range
     * @param tickUpper The upper tick of the liquidity price range
     * @param sqrtPriceX96 The square root of the current price ratio between tokens, scaled by 2^96
     * @param liquidity The desired amount of liquidity to provide
     * @param holdTokenDebt The debt amount in terms of the hold token
     * @param saleTokenBalance The balance amount of the sale token
     * @return holdTokenAmountIn The calculated required amount of hold token necessary to achieve the desired liquidity
     * @return amounts A struct containing the calculated amounts of token0 (`amounts.amount0`) and token1 (`amounts.amount1`) for the specified liquidity range
     */
    function _getHoldTokenAmountIn(
        bool zeroForSaleToken,
        int24 tickLower,
        int24 tickUpper,
        uint160 sqrtPriceX96,
        uint128 liquidity,
        uint256 holdTokenDebt,
        uint256 saleTokenBalance
    ) private pure returns (uint256 holdTokenAmountIn, Amounts memory amounts) {
        // Call getAmountsForLiquidity function from AmountsLiquidity library
        // to get the amounts of token0 and token1 for a given liquidity position
        (amounts.amount0, amounts.amount1) = AmountsLiquidity.getAmountsRoundingUpForLiquidity(
            sqrtPriceX96,
            TickMath.getSqrtRatioAtTick(tickLower),
            TickMath.getSqrtRatioAtTick(tickUpper),
            liquidity
        );

        if (saleTokenBalance < (zeroForSaleToken ? amounts.amount0 : amounts.amount1)) {
            // Calculate the holdTokenAmountIn based on the zeroForSaleToken flag
            holdTokenAmountIn = zeroForSaleToken
                ? holdTokenDebt - amounts.amount1
                : holdTokenDebt - amounts.amount0;
        }
    }

    /**
     * @dev Updates the NftPositionCache struct with data from the underlyingPositionManager contract.
     * @param zeroForSaleToken A boolean value indicating whether the token for sale is the 0th token or not.
     * @param loan The LoanInfo struct containing loan details.
     * @param cache The NftPositionCache struct to be updated.
     */
    function _upNftPositionCache(
        bool zeroForSaleToken,
        LoanInfo memory loan,
        NftPositionCache memory cache
    ) internal view {
        // Get the positions data from `PositionManager` and store it in the cache variables
        (
            ,
            cache.operator,
            cache.saleToken,
            cache.holdToken,
            cache.fee,
            cache.tickLower,
            cache.tickUpper,
            cache.liquidity,
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
    }
}
