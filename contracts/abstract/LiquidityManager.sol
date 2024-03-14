// SPDX-License-Identifier: SAL-1.0
pragma solidity 0.8.23;
import "../vendor0.8/uniswap/LiquidityAmounts.sol";
import "../vendor0.8/uniswap/TickMath.sol";
import "./ApproveSwapAndPay.sol";
import "../Vault.sol";
import { Constants } from "../libraries/Constants.sol";
import { ErrLib } from "../libraries/ErrLib.sol";
import { AmountsLiquidity } from "../libraries/AmountsLiquidity.sol";
import "../interfaces/abstract/ILiquidityManager.sol";
import "../interfaces/IWagmiLeverageFlashCallback.sol";
import "../interfaces/IFlashLoanAggregator.sol";

abstract contract LiquidityManager is
    ApproveSwapAndPay,
    ILiquidityManager,
    IWagmiLeverageFlashCallback
{
    using { ErrLib.revertError } for bool;

    /**
     * @notice The address of the vault contract.
     */
    address public immutable VAULT_ADDRESS;

    address public flashLoanAggregatorAddress;
    /**
     * @notice The Nonfungible Position Manager contract.
     */
    INonfungiblePositionManager public immutable underlyingPositionManager;
    /**
     * @notice The Quoter contract.
     */
    address public lightQuoterV3Address;

    ///  msg.sender => token => FeesAmt
    mapping(address => mapping(address => uint256)) internal loansFeesInfo;
    ///  token => FeesAmt
    mapping(address => uint256) internal platformsFeesInfo;

    /**
     * @dev Contract constructor.
     * @param _underlyingPositionManagerAddress Address of the underlying position manager contract.
     * @param _lightQuoterV3 Address of the LightQuoterV3 contract.
     * @param _underlyingV3Factory Address of the underlying V3 factory contract.
     * @param _underlyingV3PoolInitCodeHash The init code hash of the underlying V3 pool.
     */
    constructor(
        address _underlyingPositionManagerAddress,
        address _flashLoanAggregator,
        address _lightQuoterV3,
        address _underlyingV3Factory,
        bytes32 _underlyingV3PoolInitCodeHash
    ) ApproveSwapAndPay(_underlyingV3Factory, _underlyingV3PoolInitCodeHash) {
        // Assign the underlying position manager contract address
        underlyingPositionManager = INonfungiblePositionManager(_underlyingPositionManagerAddress);
        // Assign the quoter contract address
        lightQuoterV3Address = _lightQuoterV3;

        flashLoanAggregatorAddress = _flashLoanAggregator;
        // Generate a unique salt for the new Vault contract
        bytes32 salt = keccak256(abi.encode(block.timestamp, address(this)));
        // Deploy a new Vault contract using the generated salt and assign its address to VAULT_ADDRESS
        VAULT_ADDRESS = address(new Vault{ salt: salt }(Constants.FLASH_LOAN_DEFAULT_VAULT_FEE));
    }

    modifier onlyTrustedCallers() {
        (msg.sender != flashLoanAggregatorAddress && msg.sender != VAULT_ADDRESS).revertError(
            ErrLib.ErrorCode.INVALID_CALLER
        );
        _;
    }

    error InvalidLiquidityAmount(uint256 tokenId, uint128 max, uint128 min, uint128 liquidity);
    error InvalidTokens(uint256 tokenId);
    error NotApproved(uint256 tokenId);
    error InvalidRestoredLiquidity(
        uint256 tokenId,
        uint128 borrowedLiquidity,
        uint128 restoredLiquidity
    );

    function _chargePlatformFees(address holdToken, uint256 feesAmt) internal {
        unchecked {
            platformsFeesInfo[holdToken] += feesAmt * Constants.COLLATERAL_BALANCE_PRECISION;
        }
    }

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
        uint24 feeTiers,
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
        // Apply the fee tier to the borrowed amount
        feeTiers += Constants.FLASH_LOAN_FEE_COMPENSATION;
        borrowedAmount += FullMath.mulDivRoundingUp(borrowedAmount, feeTiers, 1e6 - feeTiers);
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
        uint256 entranceFeeBps,
        uint256 platformFeesBPs,
        LoanInfo[] memory loans
    )
        internal
        returns (
            uint256 borrowedAmount,
            uint256 holdTokenEntranceFee,
            uint256 holdTokenPlatformFees
        )
    {
        NftPositionCache memory cache;

        for (uint256 i; i < loans.length; ) {
            LoanInfo memory loan = loans[i];
            // Extract position-related details
            _upNftPositionCache(zeroForSaleToken, loan, cache);

            // Check operator approval
            if (cache.operator != address(this)) {
                revert NotApproved(loan.tokenId);
            }
            address creditor = _getOwnerOf(loan.tokenId);
            // Check token validity
            if (
                cache.saleToken != saleToken ||
                cache.holdToken != holdToken ||
                creditor == address(0)
            ) {
                revert InvalidTokens(loan.tokenId);
            }

            // Check borrowed liquidity validity
            uint128 minLiquidityAmt = _getMinLiquidityAmt(cache.tickLower, cache.tickUpper);
            if (loan.liquidity > cache.liquidity || loan.liquidity < minLiquidityAmt) {
                revert InvalidLiquidityAmount(
                    loan.tokenId,
                    cache.liquidity,
                    minLiquidityAmt,
                    loan.liquidity
                );
            }
            if (entranceFeeBps > 0) {
                uint256 entranceFeeAmt = FullMath.mulDivRoundingUp(
                    cache.holdTokenDebt,
                    entranceFeeBps,
                    Constants.BP
                );

                unchecked {
                    holdTokenEntranceFee += entranceFeeAmt;
                    entranceFeeAmt *= Constants.COLLATERAL_BALANCE_PRECISION;
                    uint256 platformFeesAmt = (entranceFeeAmt * platformFeesBPs) / Constants.BP;
                    holdTokenPlatformFees += platformFeesAmt;
                    loansFeesInfo[creditor][cache.holdToken] += (entranceFeeAmt - platformFeesAmt);
                }
            }

            // Calculate borrowed amount
            unchecked {
                borrowedAmount += cache.holdTokenDebt;
            }
            // Decrease liquidity and move to the next loan
            _decreaseLiquidity(loan.tokenId, loan.liquidity);

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Calculates the amounts to be swapped using a quoter contract.
     * @dev This function utilizes a static call to the quoter contract to determine the swap amounts without affecting the blockchain state.
     * @param zeroForIn A boolean to indicate if we're swapping the token at index 0 in the pool.
     * @param pool The address of the Uniswap V3 pool involved in the swap.
     * @param liquidity The amount of liquidity to provide to the pool.
     * @param tickLower The lower tick range for the position.
     * @param tickUpper The upper tick range for the position.
     * @param saleTokenBalance The balance of the token intended to sell.
     * @param holdTokenBalance The balance of the token not being sold (held).
     * @param amounts A struct to receive the calculated amounts of tokens involved in the swap.
     * @return amountIn The computed amount of input tokens that needs to be swapped.
     */
    function _calculateAmountsToSwap(
        bool zeroForIn,
        address pool,
        uint128 liquidity,
        int24 tickLower,
        int24 tickUpper,
        uint256 saleTokenBalance,
        uint256 holdTokenBalance,
        Amounts memory amounts
    ) private view returns (uint256 amountIn) {
        (, bytes memory data) = lightQuoterV3Address.staticcall(
            abi.encodeWithSelector(
                ILightQuoterV3.calculateExactZapIn.selector,
                ILightQuoterV3.CalculateExactZapInParams({
                    swapPool: pool,
                    zeroForIn: zeroForIn,
                    tickLower: tickLower,
                    tickUpper: tickUpper,
                    liquidityExactAmount: liquidity,
                    tokenInBalance: holdTokenBalance,
                    tokenOutBalance: saleTokenBalance
                })
            )
        );

        (amountIn, amounts.amount0, amounts.amount1) = abi.decode(
            data,
            (uint256, uint256, uint256)
        );
    }

    /**
     * @notice Internal function to restore liquidity using parameters and loans provided.
     * @dev Iteratively processes each loan from the list given in params, restores liquidity as per defined logic,
     *      and handles token swaps if necessary. Also updates fees information for loan creditors.
     * @param params Struct of type `RestoreLiquidityParams` containing all parameters required for the restoration.
     */
    function _restoreLiquidity(RestoreLiquidityParams memory params) internal {
        NftPositionCache memory cache;
        Amounts memory amounts;

        for (uint256 i; i < params.loans.length; ) {
            // Update the cache for the current loan
            LoanInfo memory loan = params.loans[i];

            // Get the owner of the Nonfungible Position Manager token by its tokenId
            address creditor = _getOwnerOf(loan.tokenId);
            // Check that the token is not burned
            if (creditor != address(0)) {
                _upNftPositionCache(params.zeroForSaleToken, loan, cache);

                (uint256 saleTokenBalance, uint256 holdTokenBalance) = _getPairBalance(
                    cache.saleToken,
                    cache.holdToken
                );

                {
                    uint256 liquidityOwnerReward = FullMath.mulDiv(
                        params.totalfeesOwed,
                        cache.holdTokenDebt,
                        params.totalBorrowedAmount
                    );

                    unchecked {
                        loansFeesInfo[creditor][cache.holdToken] += liquidityOwnerReward;
                    }
                    // Calculate the square root price using `_getCurrentSqrtPriceX96` function
                    uint160 sqrtPriceX96 = _getCurrentSqrtPriceX96(
                        params.zeroForSaleToken,
                        cache.saleToken,
                        cache.holdToken,
                        cache.fee
                    );

                    (amounts.amount0, amounts.amount1) = AmountsLiquidity
                        .getAmountsRoundingUpForLiquidity(
                            sqrtPriceX96,
                            TickMath.getSqrtRatioAtTick(cache.tickLower),
                            TickMath.getSqrtRatioAtTick(cache.tickUpper),
                            loan.liquidity
                        );
                }

                uint256 saleTokenAmt = params.zeroForSaleToken ? amounts.amount0 : amounts.amount1;
                // If balance is low, perform a flash loan to meet the liquidity requirements
                if (saleTokenBalance < saleTokenAmt) {
                    unchecked {
                        saleTokenAmt -= saleTokenBalance;
                    }
                    Vault(VAULT_ADDRESS).vaultFlash(
                        cache.saleToken,
                        saleTokenAmt,
                        abi.encode(
                            CallbackData({
                                zeroForSaleToken: params.zeroForSaleToken,
                                fee: cache.fee,
                                tickLower: cache.tickLower,
                                tickUpper: cache.tickUpper,
                                saleToken: cache.saleToken,
                                holdToken: cache.holdToken,
                                holdTokenDebt: cache.holdTokenDebt > holdTokenBalance
                                    ? holdTokenBalance
                                    : cache.holdTokenDebt,
                                vaultBodyDebt: uint256(0),
                                vaultFeeDebt: uint256(0),
                                amounts: amounts,
                                loan: loan,
                                routes: params.routes
                            })
                        )
                    );
                } else {
                    // Increase liquidity directly without using a flash loan
                    _increaseLiquidity(loan, amounts.amount0, amounts.amount1);
                }
            }

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev Executes a flash loan callback function for the Wagmi Leverage protocol.
     * It performs various operations based on the received flash loan data.
     * If the sale token balance is insufficient, it initiates a flash loan to borrow the required amount.
     * Otherwise, it increases liquidity and performs token swaps.
     * Finally, it charges platform fees and makes payments to the vault and flash loan aggregator contracts.
     * @param bodyAmt The amount of the flash loan body token.
     * @param feeAmt The amount of the flash loan fee token.
     * @param data The encoded flash loan callback data.
     */
    function wagmiLeverageFlashCallback(
        uint256 bodyAmt,
        uint256 feeAmt,
        bytes calldata data
    ) external onlyTrustedCallers {
        // Decoding the callback data to extract loan details and swap information
        CallbackData memory decodedData = abi.decode(data, (CallbackData));
        // Retrieve the current balance of the sale token
        uint256 saleTokenBalance = _getBalance(decodedData.saleToken);
        // Calculate the sale token amount needed based on the encoded data
        uint256 saleTokenAmt = decodedData.zeroForSaleToken
            ? decodedData.amounts.amount0
            : decodedData.amounts.amount1;
        // If the token balance is less than required, try to get more tokens through a flash loan or swap
        if (saleTokenBalance < saleTokenAmt) {
            // When there are no more routes left or the sender is the flash loan aggregator
            if (
                decodedData.routes.flashLoanParams.length == 0 ||
                msg.sender == flashLoanAggregatorAddress
            ) {
                // Compute the pool address using provided tokens and fee
                address pool = computePoolAddress(
                    decodedData.holdToken,
                    decodedData.saleToken,
                    decodedData.fee
                );
                // Calculate the amount needed for swapping hold tokens to sale tokens
                uint256 holdTokenAmountIn = _calculateAmountsToSwap(
                    !decodedData.zeroForSaleToken,
                    pool,
                    decodedData.loan.liquidity,
                    decodedData.tickLower,
                    decodedData.tickUpper,
                    saleTokenBalance,
                    decodedData.holdTokenDebt,
                    decodedData.amounts
                );
                // Perform the actual Uniswap V3 swap
                saleTokenBalance += _v3SwapExact(
                    v3SwapExactParams({
                        isExactInput: true,
                        fee: decodedData.fee,
                        tokenIn: decodedData.holdToken,
                        tokenOut: decodedData.saleToken,
                        amount: holdTokenAmountIn
                    })
                );
            } else {
                unchecked {
                    saleTokenAmt -= saleTokenBalance;
                }
                // Initiate another flash loan if additional funds are required
                IFlashLoanAggregator(flashLoanAggregatorAddress).flashLoan(
                    saleTokenAmt,
                    abi.encode(
                        CallbackData({
                            zeroForSaleToken: decodedData.zeroForSaleToken,
                            fee: decodedData.fee,
                            tickLower: decodedData.tickLower,
                            tickUpper: decodedData.tickUpper,
                            saleToken: decodedData.saleToken,
                            holdToken: decodedData.holdToken,
                            holdTokenDebt: decodedData.holdTokenDebt,
                            vaultBodyDebt: bodyAmt,
                            vaultFeeDebt: feeAmt,
                            amounts: decodedData.amounts,
                            loan: decodedData.loan,
                            routes: decodedData.routes
                        })
                    )
                );
                return; // Exit the function to wait for the new flash loan callback
            }
        }
        // Add liquidity to the Uniswap position after obtaining the required tokens
        _increaseLiquidity(
            decodedData.loan,
            decodedData.amounts.amount0,
            decodedData.amounts.amount1
        );
        // Calculate the total amount to pay back for the flash loan(s)
        uint256 amountToPay = bodyAmt +
            feeAmt +
            decodedData.vaultBodyDebt +
            decodedData.vaultFeeDebt;
        if (amountToPay > 0) {
            // Swap tokens to repay the flash loan
            uint256 holdTokenAmtIn = _v3SwapExact(
                v3SwapExactParams({
                    isExactInput: false,
                    fee: decodedData.fee,
                    tokenIn: decodedData.holdToken,
                    tokenOut: decodedData.saleToken,
                    amount: amountToPay
                })
            );
            decodedData.holdTokenDebt -= decodedData.zeroForSaleToken
                ? decodedData.amounts.amount1
                : decodedData.amounts.amount0;

            // Check for strict route adherence, revert the transaction if conditions are not met
            (decodedData.routes.strict && holdTokenAmtIn > decodedData.holdTokenDebt).revertError(
                ErrLib.ErrorCode.SWAP_AFTER_FLASH_LOAN_FAILED
            );
            // Deduct platform fees and transfer owed amounts to the vault and/or the flash loan aggregator
            if (msg.sender == flashLoanAggregatorAddress) {
                _chargePlatformFees(decodedData.saleToken, decodedData.vaultFeeDebt);
                _pay(
                    decodedData.saleToken,
                    address(this),
                    VAULT_ADDRESS,
                    decodedData.vaultBodyDebt + decodedData.vaultFeeDebt
                );
                _pay(
                    decodedData.saleToken,
                    address(this),
                    flashLoanAggregatorAddress,
                    bodyAmt + feeAmt
                );
            } else {
                // Charge only the standard flash loan fee and pay the vault
                _chargePlatformFees(decodedData.saleToken, feeAmt);
                _pay(decodedData.saleToken, address(this), VAULT_ADDRESS, bodyAmt + feeAmt);
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
     * @param loan An instance of LoanInfo memory struct containing loan details.
     * @param amount0 The amount of token0 to be added to the liquidity.
     * @param amount1 The amount of token1 to be added to the liquidity.
     */
    function _increaseLiquidity(LoanInfo memory loan, uint256 amount0, uint256 amount1) private {
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
            revert InvalidRestoredLiquidity(loan.tokenId, loan.liquidity, restoredLiquidity);
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
            cache.fee,
            cache.tickLower,
            cache.tickUpper,
            loan.liquidity
        );
    }
}
