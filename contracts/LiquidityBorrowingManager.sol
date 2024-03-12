// SPDX-License-Identifier: SAL-1.0

pragma solidity 0.8.23;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./abstract/OwnerSettings.sol";
import "./abstract/DailyRateAndCollateral.sol";
import "./libraries/ErrLib.sol";
import "./interfaces/ILiquidityBorrowingManager.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * WAGMI Leverage Protocol v2.0 beta
 * wagmi.com                                                
 * 
    /  |  _  /  | /      \  /      \ /  \     /  |/      | 
    $$ | / \ $$ |/$$$$$$  |/$$$$$$  |$$  \   /$$ |$$$$$$/ 
    $$ |/$  \$$ |$$ |__$$ |$$ | _$$/ $$$  \ /$$$ |  $$ |  
    $$ /$$$  $$ |$$    $$ |$$ |/    |$$$$  /$$$$ |  $$ |  
    $$ $$/$$ $$ |$$$$$$$$ |$$ |$$$$ |$$ $$ $$/$$ |  $$ |  
    $$$$/  $$$$ |$$ |  $$ |$$ \__$$ |$$ |$$$/ $$ | _$$ |_ 
    $$$/    $$$ |$$ |  $$ |$$    $$/ $$ | $/  $$ |/ $$   |  
    $$/      $$/ $$/   $$/  $$$$$$/  $$/      $$/ $$$$$$/  
 */

contract LiquidityBorrowingManager is
    ILiquidityBorrowingManager,
    OwnerSettings,
    DailyRateAndCollateral,
    ReentrancyGuard
{
    using { ErrLib.revertError } for bool;
    using EnumerableSet for EnumerableSet.Bytes32Set;

    /// borrowingKey=>LoanInfo
    mapping(bytes32 => LoanInfo[]) private loansInfo;
    /// borrowingKey=>BorrowingInfo
    mapping(bytes32 => BorrowingInfo) public borrowingsInfo;
    /// NonfungiblePositionManager tokenId => EnumerableSet.Bytes32Set
    mapping(uint256 => EnumerableSet.Bytes32Set) private tokenIdToBorrowingKeys;
    /// borrower => EnumerableSet.Bytes32Set
    mapping(address => EnumerableSet.Bytes32Set) private userBorrowingKeys;

    /// @dev Modifier to check if the current block timestamp is before or equal to the deadline.
    modifier checkDeadline(uint256 deadline) {
        (_blockTimestamp() > deadline).revertError(ErrLib.ErrorCode.TOO_OLD_TRANSACTION);
        _;
    }

    modifier onlyOperator() {
        (msg.sender != operator).revertError(ErrLib.ErrorCode.INVALID_CALLER);
        _;
    }

    function _blockTimestamp() internal view returns (uint256) {
        return block.timestamp;
    }

    constructor(
        address _underlyingPositionManagerAddress,
        address _flashLoanAggregator,
        address _lightQuoterV3,
        address _underlyingV3Factory,
        bytes32 _underlyingV3PoolInitCodeHash
    )
        LiquidityManager(
            _underlyingPositionManagerAddress,
            _flashLoanAggregator,
            _lightQuoterV3,
            _underlyingV3Factory,
            _underlyingV3PoolInitCodeHash
        )
    {}

    /**
     * @dev Adds or removes a swap call params to the whitelist.
     * @param swapTarget The address of the target contract for the swap call.
     * @param funcSelector The function selector of the swap call.
     * @param isAllowed A boolean indicating whether the swap call is allowed or not.
     */
    function setSwapCallToWhitelist(
        address swapTarget,
        bytes4 funcSelector,
        bool isAllowed
    ) external onlyOwner {
        (swapTarget == VAULT_ADDRESS ||
            swapTarget == address(this) ||
            swapTarget == address(underlyingPositionManager) ||
            funcSelector == IERC20.transferFrom.selector).revertError(ErrLib.ErrorCode.FORBIDDEN);
        whitelistedCall[swapTarget][funcSelector] = isAllowed;
    }

    /**
     * @notice This function allows the owner to collect protocol fees for multiple tokens
     * and transfer them to a specified recipient.
     * @dev Only the contract owner can call this function.
     * @param recipient The address of the recipient who will receive the collected fees.
     * @param tokens An array of addresses representing the tokens for which fees will be collected.
     */
    function collectProtocol(address recipient, address[] calldata tokens) external onlyOwner {
        uint256[] memory amounts = _collect(platformsFeesInfo, recipient, tokens);

        emit CollectProtocol(recipient, tokens, amounts);
    }

    /**
     * @notice This function allows the caller to collect their own loan fees for multiple tokens
     * and transfer them to themselves.
     * @param tokens An array of addresses representing the tokens for which fees will be collected.
     */
    function collectLoansFees(address[] calldata tokens) external {
        mapping(address => uint256) storage collection = loansFeesInfo[msg.sender];
        uint256[] memory amounts = _collect(collection, msg.sender, tokens);

        emit CollectLoansFees(msg.sender, tokens, amounts);
    }

    /**
     * @notice This function is used to update the daily rate for holding token for specific pair.
     * @dev Only the daily rate operator can call this function.
     * @param saleToken The address of the sale token.
     * @param holdToken The address of the hold token.
     * @param value The new value of the daily rate for the hold token will be calculated based
     * on the volatility of the pair and the popularity of loans in it
     * @dev The value must be within the range of MIN_DAILY_RATE and MAX_DAILY_RATE.
     */
    function updateHoldTokenDailyRate(
        address saleToken,
        address holdToken,
        uint256 value
    ) external onlyOperator {
        if (value > Constants.MAX_DAILY_RATE || value < Constants.MIN_DAILY_RATE) {
            revert InvalidSettingsValue(value);
        }
        // If the value is within the acceptable range, the function updates the currentDailyRate property
        // of the holdTokenRateInfo structure associated with the token pair.
        (, TokenInfo storage holdTokenRateInfo) = _updateHoldTokenRateInfo(saleToken, holdToken);
        holdTokenRateInfo.currentDailyRate = value;
        emit UpdateHoldTokenDailyRate(saleToken, holdToken, value);
    }

    function updateHoldTokenEntranceFee(
        address saleToken,
        address holdToken,
        uint256 value
    ) external onlyOperator {
        if (value > Constants.MAX_ENTRANCE_FEE_BPS + 1) {
            revert InvalidSettingsValue(value);
        }
        // If the value is within the acceptable range, the function updates the currentDailyRate property
        // of the holdTokenRateInfo structure associated with the token pair.
        (, TokenInfo storage holdTokenEntranceFeeInfo) = _updateHoldTokenRateInfo(
            saleToken,
            holdToken
        );
        holdTokenEntranceFeeInfo.entranceFeeBP = value;
        emit UpdateHoldTokeEntranceFee(saleToken, holdToken, value);
    }

    /**
     * @notice This function is used to check the daily rate collateral for a specific borrowing.
     * @param borrowingKey The key of the borrowing.
     * @return balance The balance of the daily rate collateral.
     * @return estimatedLifeTime The estimated lifetime of the collateral in seconds.
     */
    function checkDailyRateCollateral(
        bytes32 borrowingKey
    ) external view returns (int256 balance, uint256 estimatedLifeTime) {
        (, balance, estimatedLifeTime) = _getDebtInfo(borrowingKey);
        balance /= int256(Constants.COLLATERAL_BALANCE_PRECISION);
    }

    /**
     * @notice Get information about loans associated with a borrowing key
     * @dev This function retrieves an array of loan information for a given borrowing key.
     * The loans are stored in the loansInfo mapping, which is a mapping of borrowing keys to LoanInfo arrays.
     * @param borrowingKey The unique key associated with the borrowing
     * @return loans An array containing LoanInfo structs representing the loans associated with the borrowing key
     */
    function getLoansInfo(bytes32 borrowingKey) external view returns (LoanInfo[] memory loans) {
        loans = loansInfo[borrowingKey];
    }

    /**
     * @notice Retrieves the borrowing information for a specific NonfungiblePositionManager tokenId.
     * @param tokenId The unique identifier of the PositionManager token.
     * @return extinfo An array of BorrowingInfoExt structs representing the borrowing information.
     */
    function getLenderCreditsInfo(
        uint256 tokenId
    ) external view returns (BorrowingInfoExt[] memory extinfo) {
        bytes32[] memory borrowingKeys = getBorrowingKeysForTokenId(tokenId);
        extinfo = _getDebtsInfo(borrowingKeys);
    }

    /**
     * @dev Retrieves the borrowing keys associated with a token ID.
     * @param tokenId The identifier of the token.
     * @return borrowingKeys An array of borrowing keys.
     */
    function getBorrowingKeysForTokenId(
        uint256 tokenId
    ) public view returns (bytes32[] memory borrowingKeys) {
        borrowingKeys = tokenIdToBorrowingKeys[tokenId].values();
    }

    /**
     * @dev Retrieves the borrowing keys for a specific borrower.
     * @param borrower The address of the borrower.
     * @return borrowingKeys An array of borrowing keys.
     */
    function getBorrowingKeysForBorrower(
        address borrower
    ) public view returns (bytes32[] memory borrowingKeys) {
        borrowingKeys = userBorrowingKeys[borrower].values();
    }

    /**
     * @notice Retrieves the debts information for a specific borrower.
     * @param borrower The address of the borrower.
     * @return extinfo An array of BorrowingInfoExt structs representing the borrowing information.
     */
    function getBorrowerDebtsInfo(
        address borrower
    ) external view returns (BorrowingInfoExt[] memory extinfo) {
        bytes32[] memory borrowingKeys = userBorrowingKeys[borrower].values();
        extinfo = _getDebtsInfo(borrowingKeys);
    }

    /**
     * @dev Returns the number of loans associated with a given NonfungiblePositionManager tokenId.
     * @param tokenId The ID of the token.
     * @return count The total number of loans associated with the tokenId.
     */
    function getLenderCreditsCount(uint256 tokenId) external view returns (uint256 count) {
        count = tokenIdToBorrowingKeys[tokenId].length();
    }

    /**
     * @dev Returns the number of borrowings for a given borrower.
     * @param borrower The address of the borrower.
     * @return count The total number of borrowings for the borrower.
     */
    function getBorrowerDebtsCount(address borrower) external view returns (uint256 count) {
        count = userBorrowingKeys[borrower].length();
    }

    /**
     * @dev Returns the current daily rate for holding token.
     * @param saleToken The address of the token being sold.
     * @param holdToken The address of the token being held.
     * @return  holdTokenRateInfo The structured data containing detailed information for the hold token.
     */
    function getHoldTokenInfo(
        address saleToken,
        address holdToken
    ) external view returns (TokenInfo memory holdTokenRateInfo) {
        holdTokenRateInfo = _getHoldTokenInfo(saleToken, holdToken);
    }

    /**
     * @dev Returns the fees information for multiple tokens in an array.
     * @param feesOwner The address of the owner of the fees.
     * @param tokens An array of token addresses for which the fees are to be retrieved.
     * @return fees An array containing the fees for each token.
     */
    function getFeesInfo(
        address feesOwner,
        address[] calldata tokens
    ) external view returns (uint256[] memory fees) {
        mapping(address => uint256) storage collection = loansFeesInfo[feesOwner];
        fees = _getFees(collection, tokens);
    }

    /**
     * @dev Get the platform fees information for a list of tokens.
     *
     * This function returns an array of fees corresponding to the list of input tokens provided.
     * Each fee is retrieved from the `platformsFeesInfo` mapping which stores the fee for each token address.
     *
     * @param tokens An array of token addresses for which to retrieve the fees information.
     * @return fees Returns an array of fees, one per each token given as input in the same order.
     */
    function getPlatformFeesInfo(
        address[] calldata tokens
    ) external view returns (uint256[] memory fees) {
        mapping(address => uint256) storage collection = platformsFeesInfo;
        fees = _getFees(collection, tokens);
    }

    /**
     * @dev Calculates the liquidation bonus for a given token, borrowed amount, and times factor.
     * @param token The address of the token.
     * @param borrowedAmount The amount of tokens borrowed.
     * @param times The times factor to apply to the liquidation bonus calculation.
     * @return liquidationBonus The calculated liquidation bonus.
     */
    function getLiquidationBonus(
        address token,
        uint256 borrowedAmount,
        uint256 times
    ) public view returns (uint256 liquidationBonus) {
        // Retrieve liquidation bonus for the given token
        Liquidation memory liq = liquidationBonusForToken[token];
        unchecked {
            if (liq.bonusBP == 0) {
                // If there is no specific bonus for the token
                // Use default bonus
                liq.minBonusAmount = Constants.MINIMUM_AMOUNT;
                liq.bonusBP = dafaultLiquidationBonusBP;
            }
            liquidationBonus = (borrowedAmount * liq.bonusBP) / Constants.BP;

            if (liquidationBonus < liq.minBonusAmount) {
                liquidationBonus = liq.minBonusAmount;
            }
            liquidationBonus *= (times > 0 ? times : 1);
        }
    }

    /**
     * @dev Calculates the collateral amount required for a lifetime in seconds.
     *
     * @param borrowingKey The unique identifier of the borrowing.
     * @param lifetimeInSeconds The duration of the borrowing in seconds.
     * @return collateralAmt The calculated collateral amount that is needed.
     */
    function calculateCollateralAmtForLifetime(
        bytes32 borrowingKey,
        uint256 lifetimeInSeconds
    ) external view returns (uint256 collateralAmt) {
        // Retrieve the BorrowingInfo struct associated with the borrowing key
        BorrowingInfo memory borrowing = borrowingsInfo[borrowingKey];
        // Check if the borrowed position is existing
        if (borrowing.borrowedAmount > 0) {
            // Get the current daily rate for the hold token
            uint256 currentDailyRate = _getHoldTokenInfo(borrowing.saleToken, borrowing.holdToken)
                .currentDailyRate;
            // Calculate the collateral amount per second
            uint256 everySecond = _everySecond(borrowing.borrowedAmount, currentDailyRate);
            // Calculate the total collateral amount for the borrowing lifetime
            collateralAmt = FullMath.mulDivRoundingUp(
                everySecond,
                lifetimeInSeconds,
                Constants.COLLATERAL_BALANCE_PRECISION
            );
            // Ensure that the collateral amount is at least 1
            if (collateralAmt == 0) collateralAmt = 1;
        }
    }

    /**
     * @notice This function is used to increase the daily rate collateral for a specific borrowing.
     * @param borrowingKey The unique identifier of the borrowing.
     * @param collateralAmt The amount of collateral to be added.
     * @param deadline The deadline timestamp after which the transaction is considered invalid.
     */
    function increaseCollateralBalance(
        bytes32 borrowingKey,
        uint256 collateralAmt,
        uint256 deadline
    ) external checkDeadline(deadline) {
        BorrowingInfo storage borrowing = borrowingsInfo[borrowingKey];
        // Ensure that the borrowed position exists and the borrower is the message sender
        (borrowing.borrowedAmount == 0 || borrowing.borrower != address(msg.sender)).revertError(
            ErrLib.ErrorCode.INVALID_BORROWING_KEY
        );
        // Increase the daily rate collateral balance by the specified collateral amount
        borrowing.dailyRateCollateralBalance +=
            collateralAmt *
            Constants.COLLATERAL_BALANCE_PRECISION;
        _pay(borrowing.holdToken, msg.sender, VAULT_ADDRESS, collateralAmt);
        emit IncreaseCollateralBalance(msg.sender, borrowingKey, collateralAmt);
    }

    /**
     * @notice Borrow function allows a user to borrow tokens by providing collateral and taking out loans.
     * The trader opens a long position by borrowing the liquidity of Uniswap V3 and extracting it into a pair of tokens,
     * one of which will be swapped into a desired(holdToken).The tokens will be kept in storage until the position is closed.
     * The margin is calculated on the basis that liquidity must be restored with any price movement.
     * The time the position is held is paid by the trader.
     * @dev Emits a Borrow event upon successful borrowing.
     * @param params The BorrowParams struct containing the necessary parameters for borrowing.
     * @param deadline The deadline timestamp after which the transaction is considered invalid.
     *
     * @return borrowedAmount The total amount of `params.holdToken` borrowed.
     * @return marginDeposit The required collateral deposit amount for initiating the loan.
     * @return liquidationBonus An additional amount added to the debt as a bonus in case of liquidation.
     * @return dailyRateCollateral The collateral deposit to hold the transaction for a day.
     */
    function borrow(
        BorrowParams calldata params,
        uint256 deadline
    )
        external
        nonReentrant
        checkDeadline(deadline)
        returns (uint256, uint256, uint256, uint256, uint256)
    {
        BorrowCache memory cache;
        BorrowingInfo storage borrowing;
        {
            // Update the token rate information and retrieve the dailyRate and TokenInfo for the holdTokenRateInfo
            TokenInfo storage holdTokenRateInfo;
            (cache.dailyRateCollateral, holdTokenRateInfo) = _updateHoldTokenRateInfo(
                params.saleToken,
                params.holdToken
            );
            uint256 entranceFee = _checkEntranceFee(holdTokenRateInfo.entranceFeeBP);
            // Precalculating borrowing details and storing them in cache
            _precalculateBorrowing(cache, params, entranceFee);

            // Initializing borrowing variables and obtaining borrowing key
            borrowing = borrowingsInfo[cache.borrowingKey];
            _initOrUpdateBorrowing(
                params.saleToken,
                params.holdToken,
                params.maxDailyRate,
                cache,
                borrowing,
                holdTokenRateInfo
            );
        }
        uint256 liquidationBonus;
        {
            // Adding borrowing key and loans information to storage
            uint256 pushCounter = _addKeysAndLoansInfo(cache.borrowingKey, params.loans);
            // Calculating liquidation bonus based on hold token, borrowed amount, and number of used loans
            liquidationBonus = getLiquidationBonus(
                params.holdToken,
                cache.borrowedAmount,
                pushCounter
            );
        }
        uint256 marginDeposit;
        // positive slippage
        if (cache.holdTokenBalance > cache.borrowedAmount) {
            // Thus, we stimulate the platform to look for the best conditions for swapping on external aggregators.
            platformsFeesInfo[params.holdToken] +=
                (cache.holdTokenBalance - cache.borrowedAmount) *
                Constants.COLLATERAL_BALANCE_PRECISION;
        } else {
            unchecked {
                marginDeposit = cache.borrowedAmount - cache.holdTokenBalance;
            }
            (marginDeposit > params.maxMarginDeposit).revertError(
                ErrLib.ErrorCode.TOO_BIG_MARGIN_DEPOSIT
            );
        }

        uint256 amountToPay;
        unchecked {
            // Updating borrowing details
            borrowing.borrowedAmount += cache.borrowedAmount;
            borrowing.liquidationBonus += liquidationBonus;
            // Transfer the required tokens to the VAULT_ADDRESS for collateral and holdTokenBalance
            borrowing.dailyRateCollateralBalance +=
                cache.dailyRateCollateral *
                Constants.COLLATERAL_BALANCE_PRECISION;
            amountToPay =
                marginDeposit +
                liquidationBonus +
                cache.dailyRateCollateral +
                cache.holdTokenEntranceFee;
        }
        _pay(params.holdToken, msg.sender, VAULT_ADDRESS, amountToPay);
        // Transferring holdTokenBalance to VAULT_ADDRESS
        _pay(params.holdToken, address(this), VAULT_ADDRESS, cache.holdTokenBalance);
        // Emit the Borrow event with the borrower, borrowing key, and borrowed amount
        emit Borrow(
            msg.sender,
            cache.borrowingKey,
            cache.borrowedAmount,
            marginDeposit,
            liquidationBonus,
            cache.dailyRateCollateral,
            cache.holdTokenEntranceFee
        );
        return (
            cache.borrowedAmount,
            marginDeposit,
            liquidationBonus,
            cache.dailyRateCollateral,
            cache.holdTokenEntranceFee
        );
    }

    /**
     * @notice Allows lenders to harvest the fees accumulated from their loans.
     * @dev Retrieves and updates fee amounts for all loans associated with a borrowing position.
     * The function iterates through each loan, calculating and updating the amount of fees due.
     *
     * Requirements:
     * - The borrowingKey must correspond to an active and valid borrowing position.
     * - The collateral balance must be above zero or the current fees must be above the minimum required amount.
     *
     * @param borrowingKey The unique identifier for the specific borrowing position.
     *
     * @return harvestedAmt The total amount of fees harvested by the borrower.
     */
    function harvest(bytes32 borrowingKey) external nonReentrant returns (uint256 harvestedAmt) {
        BorrowingInfo storage borrowing = borrowingsInfo[borrowingKey];
        // Check if the borrowing key is valid
        _existenceCheck(borrowing.borrowedAmount);

        // Update token rate information and get holdTokenRateInfo storage reference
        (, TokenInfo storage holdTokenRateInfo) = _updateHoldTokenRateInfo(
            borrowing.saleToken,
            borrowing.holdToken
        );
        return _harvest(borrowingKey, borrowing, holdTokenRateInfo);
    }

    /**
     * @notice Used for repaying loans, optionally with liquidation or emergency liquidity withdrawal.
     * The position is closed either by the trader or by the liquidator if the trader has not paid for holding the position
     * and the moment of liquidation has arrived.The positions borrowed from liquidation providers are restored from the held
     * token and the remainder is sent to the caller.In the event of liquidation, the liquidity provider
     * whose liquidity is present in the trader’s position can use the emergency mode and withdraw their liquidity.In this case,
     * he will receive hold tokens and liquidity will not be restored in the uniswap pool.
     * @param params The repayment parameters including
     *  activation of the emergency liquidity restoration mode (available only to the lender)
     *  internal swap pool fee,
     *  external swap parameters,
     *  borrowing key,
     *  swap slippage allowance.
     * @param deadline The deadline by which the repayment must be made.
     *
     * @return saleTokenOut The amount of saleToken returned back to the user after repayment.
     * @return holdTokenOut The amount of holdToken returned back to the user after repayment or emergency withdrawal.
     */
    function repay(
        RepayParams calldata params,
        uint256 deadline
    )
        external
        nonReentrant
        checkDeadline(deadline)
        returns (uint256 saleTokenOut, uint256 holdTokenOut)
    {
        BorrowingInfo memory borrowing = borrowingsInfo[params.borrowingKey];
        // Check if the borrowing key is valid
        _existenceCheck(borrowing.borrowedAmount);

        bool zeroForSaleToken = borrowing.saleToken < borrowing.holdToken;
        uint256 liquidationBonus = borrowing.liquidationBonus;
        int256 collateralBalance;
        uint256 currentFees;
        // Update token rate information and get holdTokenRateInfo storage reference
        (, TokenInfo storage holdTokenRateInfo) = _updateHoldTokenRateInfo(
            borrowing.saleToken,
            borrowing.holdToken
        );
        bool underLiquidation;
        {
            // Calculate collateral balance and validate caller
            uint256 accLoanRatePerSeconds = holdTokenRateInfo.accLoanRatePerSeconds;

            (collateralBalance, currentFees) = _calculateCollateralBalance(
                borrowing.borrowedAmount,
                borrowing.accLoanRatePerSeconds,
                borrowing.dailyRateCollateralBalance,
                accLoanRatePerSeconds
            );
            underLiquidation = collateralBalance < 0;

            (msg.sender != borrowing.borrower && !underLiquidation).revertError(
                ErrLib.ErrorCode.INVALID_CALLER
            );

            // Calculate liquidation bonus and adjust fees owed
            if (collateralBalance > 0) {
                unchecked {
                    liquidationBonus +=
                        uint256(collateralBalance) /
                        Constants.COLLATERAL_BALANCE_PRECISION;
                }
            } else {
                currentFees = borrowing.dailyRateCollateralBalance;
            }
        }
        // Check if it's an emergency repayment
        if (params.isEmergency) {
            (!underLiquidation).revertError(ErrLib.ErrorCode.FORBIDDEN);
            (
                uint256 removedAmt,
                uint256 feesAmt,
                bool completeRepayment
            ) = _calculateEmergencyLoanClosure(
                    zeroForSaleToken,
                    params.borrowingKey,
                    currentFees,
                    borrowing.borrowedAmount
                );
            (removedAmt == 0).revertError(ErrLib.ErrorCode.LIQUIDITY_IS_ZERO);
            // Subtract the removed amount and fees from borrowedAmount and feesOwed
            borrowing.borrowedAmount -= removedAmt;
            borrowing.dailyRateCollateralBalance -= feesAmt;
            feesAmt =
                _pickUpPlatformFees(borrowing.holdToken, feesAmt) /
                Constants.COLLATERAL_BALANCE_PRECISION;
            // Deduct the removed amount from totalBorrowed
            unchecked {
                holdTokenRateInfo.totalBorrowed -= removedAmt;
            }
            // If loansInfoLength is 0, remove the borrowing key from storage and get the liquidation bonus
            if (completeRepayment) {
                LoanInfo[] memory empty;
                _removeKeysAndClearStorage(borrowing.borrower, params.borrowingKey, empty);
                feesAmt =
                    _pickUpPlatformFees(borrowing.holdToken, currentFees) /
                    Constants.COLLATERAL_BALANCE_PRECISION +
                    liquidationBonus;
            } else {
                // make changes to the storage
                BorrowingInfo storage borrowingStorage = borrowingsInfo[params.borrowingKey];
                borrowingStorage.dailyRateCollateralBalance = borrowing.dailyRateCollateralBalance;
                borrowingStorage.borrowedAmount = borrowing.borrowedAmount;
            }
            unchecked {
                holdTokenOut = removedAmt + feesAmt;
            }
            // Transfer removedAmt + feesAmt to msg.sender and emit EmergencyLoanClosure event
            Vault(VAULT_ADDRESS).transferToken(borrowing.holdToken, msg.sender, holdTokenOut);
            emit EmergencyLoanClosure(borrowing.borrower, msg.sender, params.borrowingKey);
        } else {
            // Calculate platform fees and adjust fees owed
            currentFees = _pickUpPlatformFees(borrowing.holdToken, currentFees);
            // Deduct borrowedAmount from totalBorrowed
            unchecked {
                holdTokenRateInfo.totalBorrowed -= borrowing.borrowedAmount;
            }

            // Transfer the borrowed amount and liquidation bonus from the VAULT to this contract
            Vault(VAULT_ADDRESS).transferToken(
                borrowing.holdToken,
                address(this),
                borrowing.borrowedAmount + liquidationBonus
            );

            // Restore liquidity using the borrowed amount and pay a daily rate fee
            LoanInfo[] memory loans = loansInfo[params.borrowingKey];

            _maxApproveIfNecessary(borrowing.holdToken, address(underlyingPositionManager));
            _maxApproveIfNecessary(borrowing.saleToken, address(underlyingPositionManager));

            _restoreLiquidity(
                RestoreLiquidityParams({
                    zeroForSaleToken: zeroForSaleToken,
                    totalfeesOwed: currentFees,
                    totalBorrowedAmount: borrowing.borrowedAmount,
                    routes: params.routes,
                    loans: loans
                })
            );

            // Remove borrowing key from related data structures
            _removeKeysAndClearStorage(borrowing.borrower, params.borrowingKey, loans);

            // Get the remaining balance of saleToken and holdToken
            (saleTokenOut, holdTokenOut) = _getPairBalance(
                borrowing.saleToken,
                borrowing.holdToken
            );

            (holdTokenOut < params.minHoldTokenOut || saleTokenOut < params.minSaleTokenOut)
                .revertError(ErrLib.ErrorCode.PRICE_SLIPPAGE_CHECK);

            // Pay a profit to a msg.sender
            _pay(borrowing.holdToken, address(this), msg.sender, holdTokenOut);
            _pay(borrowing.saleToken, address(this), msg.sender, saleTokenOut);

            emit Repay(borrowing.borrower, msg.sender, params.borrowingKey);
        }
    }

    /// @notice Calculates the collateral balance, picks up platform fees, updates rates, and distributes the fees to creditors.
    /// @custom:throw "FORBIDDEN" When the calculated collateral balance is less than or equal to zero, indicating the caller is not allowed to initiate harvest.
    function _harvest(
        bytes32 borrowingKey,
        BorrowingInfo storage borrowing,
        TokenInfo storage holdTokenRateInfo
    ) private returns (uint256 harvestedAmt) {
        // Calculate collateral balance and validate caller
        (int256 collateralBalance, uint256 currentFees) = _calculateCollateralBalance(
            borrowing.borrowedAmount,
            borrowing.accLoanRatePerSeconds,
            borrowing.dailyRateCollateralBalance,
            holdTokenRateInfo.accLoanRatePerSeconds
        );
        (collateralBalance <= 0).revertError(ErrLib.ErrorCode.FORBIDDEN);

        // Calculate platform fees and adjust fees owed
        unchecked {
            borrowing.dailyRateCollateralBalance -= currentFees;
        }
        uint256 feesOwed = _pickUpPlatformFees(borrowing.holdToken, currentFees);
        // Set the accumulated loan rate per second for the borrowing position
        borrowing.accLoanRatePerSeconds = holdTokenRateInfo.accLoanRatePerSeconds;

        uint256 borrowedAmount = borrowing.borrowedAmount;

        bool zeroForSaleToken = borrowing.saleToken < borrowing.holdToken;

        // Create a memory struct to store liquidity cache information.
        NftPositionCache memory cache;
        // Get the array of LoanInfo structs associated with the given borrowing key.
        LoanInfo[] memory loans = loansInfo[borrowingKey];
        // Iterate through each loan in the loans array.
        for (uint256 i; i < loans.length; ) {
            LoanInfo memory loan = loans[i];
            // Get the owner address of the loan's token ID using the underlyingPositionManager contract.
            address creditor = _getOwnerOf(loan.tokenId);
            // Check if the owner of the loan's token ID is equal to the `msg.sender`.
            if (creditor != address(0)) {
                // Update the liquidity cache based on the loan information.
                _upNftPositionCache(zeroForSaleToken, loan, cache);
                uint256 feesAmt = FullMath.mulDiv(feesOwed, cache.holdTokenDebt, borrowedAmount);
                // Calculate the fees amount based on the total fees owed and holdTokenDebt.
                unchecked {
                    loansFeesInfo[creditor][cache.holdToken] += feesAmt;
                    harvestedAmt += feesAmt;
                }
            }
            unchecked {
                ++i;
            }
        }

        emit Harvest(borrowingKey, harvestedAmt);
    }

    /**
     * @notice Calculates the amount to be repaid in an emergency situation.
     * @dev This function removes loans associated with a borrowing key owned by the `msg.sender`.
     * @param zeroForSaleToken A boolean value indicating whether the token for sale is the 0th token or not.
     * @param borrowingKey The identifier for the borrowing key.
     * @param totalfeesOwed The total fees owed.
     * @param totalBorrowedAmount The total borrowed amount.
     * @return removedAmt The amount of debt removed from the loan.
     * @return feesAmt The calculated fees amount.
     * @return completeRepayment indicates the complete closure of the debtor's position
     */
    function _calculateEmergencyLoanClosure(
        bool zeroForSaleToken,
        bytes32 borrowingKey,
        uint256 totalfeesOwed,
        uint256 totalBorrowedAmount
    ) private returns (uint256 removedAmt, uint256 feesAmt, bool completeRepayment) {
        // Create a memory struct to store liquidity cache information.
        NftPositionCache memory cache;
        // Get the array of LoanInfo structs associated with the given borrowing key.
        LoanInfo[] storage loans = loansInfo[borrowingKey];
        // Iterate through each loan in the loans array.
        for (uint256 i; i < loans.length; ) {
            LoanInfo memory loan = loans[i];
            // Get the owner address of the loan's token ID using the underlyingPositionManager contract.
            address creditor = _getOwnerOf(loan.tokenId);
            // Check if the owner of the loan's token ID is equal to the `msg.sender`.
            if (creditor == msg.sender) {
                // If the owner matches the `msg.sender`, replace the current loan with the last loan in the loans array
                // and remove the last element.
                loans[i] = loans[loans.length - 1];
                loans.pop();
                // Remove the borrowing key from the tokenIdToBorrowingKeys mapping.
                tokenIdToBorrowingKeys[loan.tokenId].remove(borrowingKey);
                // Update the liquidity cache based on the loan information.
                _upNftPositionCache(zeroForSaleToken, loan, cache);
                // Add the holdTokenDebt value to the removedAmt.
                unchecked {
                    removedAmt += cache.holdTokenDebt;
                    // Calculate the fees amount based on the total fees owed and holdTokenDebt.
                    feesAmt += FullMath.mulDiv(
                        totalfeesOwed,
                        cache.holdTokenDebt,
                        totalBorrowedAmount
                    );
                }
            } else {
                // If the owner of the loan's token ID is not equal to the `msg.sender`,
                // the function increments the loop counter and moves on to the next loan.
                unchecked {
                    ++i;
                }
            }
        }
        // Check if all loans have been removed, indicating complete repayment.
        completeRepayment = loans.length == 0;
    }

    /**
     * @dev This internal function is used to remove borrowing keys and clear related storage for a specific
     * borrower and borrowing key.
     * @param borrower The address of the borrower.
     * @param borrowingKey The borrowing key to be removed.
     * @param loans An array of LoanInfo structs representing the loans associated with the borrowing key.
     */
    function _removeKeysAndClearStorage(
        address borrower,
        bytes32 borrowingKey,
        LoanInfo[] memory loans
    ) private {
        // Remove the borrowing key from the tokenIdToBorrowingKeys mapping for each loan in the loans array.
        for (uint256 i; i < loans.length; ) {
            tokenIdToBorrowingKeys[loans[i].tokenId].remove(borrowingKey);
            unchecked {
                ++i;
            }
        }
        // Remove the borrowing key from the userBorrowingKeys mapping for the borrower.
        userBorrowingKeys[borrower].remove(borrowingKey);
        // Delete the borrowing information and loans associated with the borrowing key from the borrowingsInfo
        // and loansInfo mappings.
        delete borrowingsInfo[borrowingKey];
        delete loansInfo[borrowingKey];
    }

    /**
     * @dev This internal function is used to add borrowing keys and loan information for a specific borrowing key.
     * @param borrowingKey The borrowing key to be added or updated.
     * @param sourceLoans An array of LoanInfo structs representing the loans to be associated with the borrowing key.
     */
    function _addKeysAndLoansInfo(
        bytes32 borrowingKey,
        LoanInfo[] memory sourceLoans
    ) private returns (uint256 pushCounter) {
        // Get the storage reference to the loans array for the borrowing key
        LoanInfo[] storage loans = loansInfo[borrowingKey];
        // Iterate through the sourceLoans array
        for (uint256 i; i < sourceLoans.length; ) {
            // Get the current loan from the sourceLoans array
            LoanInfo memory loan = sourceLoans[i];
            // Get the storage reference to the tokenIdLoansKeys array for the loan's token ID
            if (tokenIdToBorrowingKeys[loan.tokenId].add(borrowingKey)) {
                // Push the current loan to the loans array
                loans.push(loan);
                unchecked {
                    pushCounter++;
                }
            } else {
                // If already exists, find the loan and update its liquidity
                for (uint256 j; j < loans.length; ) {
                    if (loans[j].tokenId == loan.tokenId) {
                        unchecked {
                            loans[j].liquidity += loan.liquidity;
                        }
                        break;
                    }
                    unchecked {
                        ++j;
                    }
                }
            }
            unchecked {
                ++i;
            }
        }
        // Ensure that the number of loans does not exceed the maximum limit
        (loans.length > Constants.MAX_NUM_LOANS_PER_POSITION).revertError(
            ErrLib.ErrorCode.TOO_MANY_LOANS_PER_POSITION
        );
        // Add the borrowing key to the userBorrowingKeys mapping for the borrower if it does not exist
        userBorrowingKeys[msg.sender].add(borrowingKey);
    }

    /**
     * @dev This internal function is used to precalculate borrowing parameters and update the cache.
     * @param cache The current state of the BorrowCache struct that needs to be updated.
     * @param params The BorrowParams struct containing the essential borrowing parameters.
     * @param entranceFee The fee amount which is applied when borrowing.
     */
    function _precalculateBorrowing(
        BorrowCache memory cache,
        BorrowParams calldata params,
        uint256 entranceFee
    ) private {
        // Compute the borrowingKey using the msg.sender, saleToken, and holdToken
        cache.borrowingKey = Keys.computeBorrowingKey(
            msg.sender,
            params.saleToken,
            params.holdToken
        );
        {
            bool zeroForSaleToken = params.saleToken < params.holdToken;
            // Create a storage reference for the hold token rate information

            // Extract liquidity and store the borrowed amount in the cache
            uint256 holdTokenPlatformFee;
            (
                cache.borrowedAmount,
                cache.holdTokenEntranceFee,
                holdTokenPlatformFee
            ) = _extractLiquidity(
                zeroForSaleToken,
                params.saleToken,
                params.holdToken,
                entranceFee,
                platformFeesBP,
                params.loans
            );

            // the empty loans[] disallowed
            (cache.borrowedAmount == 0).revertError(ErrLib.ErrorCode.LOANS_IS_EMPTY);
            // Increment the total borrowed amount for the hold token information
            unchecked {
                platformsFeesInfo[params.holdToken] += holdTokenPlatformFee;
            }
        }

        if (params.externalSwap.length != 0) {
            // Call the external swap function
            _callExternalSwap(params.saleToken, params.externalSwap);
        }
        uint256 saleTokenBalance;
        // Get the balance of the sale token and hold token in the pair
        (saleTokenBalance, cache.holdTokenBalance) = _getPairBalance(
            params.saleToken,
            params.holdToken
        );
        // Check if the sale token balance is greater than 0
        if (saleTokenBalance > 0) {
            // Call the internal v3SwapExactInput function and update the hold token balance in the cache
            cache.holdTokenBalance += _v3SwapExact(
                v3SwapExactParams({
                    isExactInput: true,
                    fee: params.internalSwapPoolfee,
                    tokenIn: params.saleToken,
                    tokenOut: params.holdToken,
                    amount: saleTokenBalance
                })
            );
        }

        // Ensure that the received holdToken balance meets the minimum required
        if (cache.holdTokenBalance < params.minHoldTokenOut) {
            revert TooLittleReceivedError(params.minHoldTokenOut, cache.holdTokenBalance);
        }
    }

    /**
     * @dev This internal function is used to initialize or update the borrowing process for a given saleToken and holdToken combination.
     * It computes the borrowingKey, retrieves the BorrowingInfo from borrowingsInfo mapping,
     * and updates the BorrowingInfo based on the current state of the borrowing.
     * @param saleToken The address of the token being sold.
     * @param holdToken The address of the token used as collateral.
     * @param maxDailyRate The maximum allowed daily rate for the borrowing.
     * @param cache A memory-struct holding temporary data to minimize the number of storage reads.
     * @param borrowing A reference to the updated BorrowingInfo struct from the `borrowingsInfo`
     * mapping, corresponding to the computed borrowing key.
     * @param holdTokenRateInfo A storage reference to the TokenInfo struct containing
     * interest rate information about the holdToken being used.
     */
    function _initOrUpdateBorrowing(
        address saleToken,
        address holdToken,
        uint256 maxDailyRate,
        BorrowCache memory cache,
        BorrowingInfo storage borrowing,
        TokenInfo storage holdTokenRateInfo
    ) private {
        (cache.dailyRateCollateral > maxDailyRate).revertError(ErrLib.ErrorCode.TOO_BIG_DAILY_RATE);

        // Calculate the prepayment per day fees based on the borrowed amount and daily rate collateral
        cache.dailyRateCollateral = FullMath.mulDivRoundingUp(
            cache.borrowedAmount,
            cache.dailyRateCollateral,
            Constants.BP
        );

        // update
        if (borrowing.borrowedAmount > 0) {
            // Ensure that the borrower of the existing borrowing position matches the msg.sender
            (borrowing.borrower != address(msg.sender)).revertError(
                ErrLib.ErrorCode.INVALID_BORROWING_KEY
            );
            _harvest(cache.borrowingKey, borrowing, holdTokenRateInfo);
        } else {
            // Initialize the BorrowingInfo for the new position
            borrowing.borrower = msg.sender;
            borrowing.saleToken = saleToken;
            borrowing.holdToken = holdToken;
            // Set the accumulated loan rate per second for the borrowing position
            borrowing.accLoanRatePerSeconds = holdTokenRateInfo.accLoanRatePerSeconds;
        }

        holdTokenRateInfo.totalBorrowed += cache.borrowedAmount;
        (holdTokenRateInfo.totalBorrowed > type(uint160).max).revertError(
            ErrLib.ErrorCode.TOO_MUCH_TOTAL_BORROW
        );
    }

    /**
     * @dev This internal function is used to pick up platform fees from the given fees amount.
     * It calculates the platform fees based on the fees and platformFeesBP (basis points) variables,
     * updates the platformsFeesInfo mapping with the platform fees for the holdToken,
     * and returns the remaining fees after deducting the platform fees.
     * @param holdToken The address of the hold token.
     * @param fees The total fees amount.
     * @return currentFees The remaining fees after deducting the platform fees.
     */
    function _pickUpPlatformFees(
        address holdToken,
        uint256 fees
    ) private returns (uint256 currentFees) {
        uint256 platformFees = (fees * platformFeesBP) / Constants.BP;
        unchecked {
            platformsFeesInfo[holdToken] += platformFees;
            currentFees = fees - platformFees;
        }
    }

    /**
     * @dev This internal function is used to get information about a specific debt.
     * It retrieves the borrowing information from the borrowingsInfo mapping based on the borrowingKey,
     * calculates the current daily rate and hold token rate info using the _getHoldTokenInfo function,
     * calculates the collateral balance using the _calculateCollateralBalance function,
     * and calculates the estimated lifetime of the debt if the collateral balance is greater than zero.
     * @param borrowingKey The unique key associated with the debt.
     * @return borrowing The struct containing information about the debt.
     * @return collateralBalance The calculated collateral balance for the debt.
     * @return estimatedLifeTime The estimated number of seconds the debt will last based on the collateral balance.
     */
    function _getDebtInfo(
        bytes32 borrowingKey
    )
        private
        view
        returns (
            BorrowingInfo memory borrowing,
            int256 collateralBalance,
            uint256 estimatedLifeTime
        )
    {
        // Retrieve the borrowing information from the borrowingsInfo mapping based on the borrowingKey
        borrowing = borrowingsInfo[borrowingKey];
        // Calculate the current daily rate and hold token rate info using the _getHoldTokenInfo function
        TokenInfo memory holdTokenRateInfo = _getHoldTokenInfo(
            borrowing.saleToken,
            borrowing.holdToken
        );

        (collateralBalance, ) = _calculateCollateralBalance(
            borrowing.borrowedAmount,
            borrowing.accLoanRatePerSeconds,
            borrowing.dailyRateCollateralBalance,
            holdTokenRateInfo.accLoanRatePerSeconds
        );
        // Calculate the estimated lifetime of the debt if the collateral balance is greater than zero
        if (collateralBalance > 0) {
            uint256 everySecond = _everySecond(
                borrowing.borrowedAmount,
                holdTokenRateInfo.currentDailyRate
            );

            estimatedLifeTime = uint256(collateralBalance) / everySecond;
            if (estimatedLifeTime == 0) estimatedLifeTime = 1;
        }
    }

    function _everySecond(
        uint256 borrowedAmount,
        uint256 currentDailyRate
    ) private pure returns (uint256 everySecond) {
        unchecked {
            everySecond = FullMath.mulDivRoundingUp(
                borrowedAmount,
                currentDailyRate * Constants.COLLATERAL_BALANCE_PRECISION,
                1 days * Constants.BP
            );
        }
    }

    function _getFees(
        mapping(address => uint256) storage collection,
        address[] calldata tokens
    ) internal view returns (uint256[] memory fees) {
        fees = new uint256[](tokens.length);
        for (uint256 i; i < tokens.length; ) {
            address token = tokens[i];
            uint256 amount = collection[token];
            fees[i] = amount;
            unchecked {
                ++i;
            }
        }
    }

    /// @notice Retrieves the debt information for the specified borrowing keys.
    /// @param borrowingKeys The array of borrowing keys to retrieve the debt information for.
    /// @return extinfo An array of BorrowingInfoExt structs representing the borrowing information.
    function _getDebtsInfo(
        bytes32[] memory borrowingKeys
    ) private view returns (BorrowingInfoExt[] memory extinfo) {
        extinfo = new BorrowingInfoExt[](borrowingKeys.length);
        for (uint256 i; i < borrowingKeys.length; ) {
            bytes32 key = borrowingKeys[i];
            extinfo[i].key = key;
            extinfo[i].loans = loansInfo[key];
            (
                extinfo[i].info,
                extinfo[i].collateralBalance,
                extinfo[i].estimatedLifeTime
            ) = _getDebtInfo(key);
            unchecked {
                ++i;
            }
        }
    }

    function _existenceCheck(uint256 borrowedAmount) private pure {
        (borrowedAmount == 0).revertError(ErrLib.ErrorCode.INVALID_BORROWING_KEY);
    }

    function _collect(
        mapping(address => uint256) storage collection,
        address recipient,
        address[] calldata tokens
    ) private returns (uint256[] memory amounts) {
        amounts = new uint256[](tokens.length);
        for (uint256 i; i < tokens.length; ) {
            address token = tokens[i];
            uint256 amount;
            unchecked {
                amount = collection[token] / Constants.COLLATERAL_BALANCE_PRECISION;
            }
            if (amount > 0) {
                collection[token] = 0;
                amounts[i] = amount;
                Vault(VAULT_ADDRESS).transferToken(token, recipient, amount);
            }
            unchecked {
                ++i;
            }
        }
    }
}
