// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "./abstract/LiquidityManager.sol";
import "./abstract/OwnerSettings.sol";
import "./abstract/DailyRateAndCollateral.sol";
import "./libraries/ErrLib.sol";

// import "hardhat/console.sol";

/**
 * @title LiquidityBorrowingManager
 * @dev This contract manages the borrowing liquidity functionality for WAGMI Leverage protocol.
 * It inherits from LiquidityManager, OwnerSettings, DailyRateAndCollateral, and ReentrancyGuard contracts.
 */
contract LiquidityBorrowingManager is
    LiquidityManager,
    OwnerSettings,
    DailyRateAndCollateral,
    ReentrancyGuard
{
    using { Keys.removeKey, Keys.addKeyIfNotExists } for bytes32[];
    using { ErrLib.revertError } for bool;

    /// @title BorrowParams
    /// @notice This struct represents the parameters required for borrowing.
    struct BorrowParams {
        /// @notice The pool fee level for the internal swap
        uint24 internalSwapPoolfee;
        /// @notice The address of the token that will be sold to obtain the loan currency
        address saleToken;
        /// @notice The address of the token that will be held
        address holdToken;
        /// @notice The minimum amount of holdToken that must be obtained
        uint256 minHoldTokenOut;
        /// @notice The maximum amount of collateral that can be provided for the loan
        uint256 maxCollateral;
        /// @notice The SwapParams struct representing the external swap parameters
        SwapParams externalSwap;
        /// @notice An array of LoanInfo structs representing multiple loans
        LoanInfo[] loans;
    }
    /// @title BorrowingInfo
    /// @notice This struct represents the borrowing information for a borrower.
    struct BorrowingInfo {
        address borrower;
        address saleToken;
        address holdToken;
        /// @notice The amount of fees owed by the creditor
        uint256 feesOwed;
        /// @notice The amount borrowed by the borrower
        uint256 borrowedAmount;
        /// @notice The liquidation bonus
        uint256 liquidationBonus;
        /// @notice The accumulated loan rate per share
        uint256 accLoanRatePerSeconds;
        /// @notice The daily rate collateral balance multiplied by COLLATERAL_BALANCE_PRECISION
        uint256 dailyRateCollateralBalance;
    }
    /// @notice This struct used for caching variables inside a function 'borrow'
    struct BorrowCache {
        uint256 dailyRateCollateral;
        uint256 accLoanRatePerSeconds;
        uint256 borrowedAmount;
        uint256 holdTokenBalance;
    }
    /// @notice Struct representing the extended borrowing information.
    struct BorrowingInfoExt {
        /// @notice The main borrowing information.
        BorrowingInfo info;
        /// @notice An array of LoanInfo structs representing multiple loans
        LoanInfo[] loans;
        /// @notice The balance of the collateral.
        int256 collateralBalance;
        /// @notice The estimated lifetime of the loan.
        uint256 estimatedLifeTime;
        /// borrowing Key
        bytes32 key;
    }

    /// @title RepayParams
    /// @notice This struct represents the parameters required for repaying a loan.
    struct RepayParams {
        /// @notice The activation of the emergency liquidity restoration mode (available only to the lender)
        bool isEmergency;
        /// @notice The pool fee level for the internal swap
        uint24 internalSwapPoolfee;
        /// @notice The external swap parameters for the repayment transaction
        SwapParams externalSwap;
        /// @notice The unique borrowing key associated with the loan
        bytes32 borrowingKey;
        /// @notice The slippage allowance for the swap in basis points (1/10th of a percent)
        uint256 swapSlippageBP1000;
    }

    mapping(bytes32 => LoanInfo[]) public loansInfo;
    /// borrowingKey=>BorrowingInfo
    mapping(bytes32 => BorrowingInfo) public borrowingsInfo;
    /// borrower => BorrowingKeys[]
    mapping(address => bytes32[]) public userBorrowingKeys;
    /// tokenId => BorrowingKeys[]
    mapping(uint256 => bytes32[]) public tokenIdToBorrowingKeys;

    ///  token => FeesAmt
    mapping(address => uint256) private platformsFeesInfo;

    event Borrow(
        address borrower,
        bytes32 borrowingKey,
        uint256 borrowedAmount,
        uint256 borrowingCollateral,
        uint256 liquidationBonus,
        uint256 dailyRatePrepayment
    );

    event Repay(address borrower, address liquidator, bytes32 borrowingKey);
    event EmergencyLoanClosure(address borrower, address lender, bytes32 borrowingKey);
    event CollectProtocol(address recipient, address[] tokens, uint256[] amounts);
    event UpdateHoldTokenDailyRate(address saleToken, address holdToken, uint256 value);
    event IncreaseCollateralBalance(address borrower, bytes32 borrowingKey, uint256 collateralAmt);
    event TakeOverDebt(
        address oldBorrower,
        address newBorrower,
        bytes32 oldBorrowingKey,
        bytes32 newBorrowingKey
    );

    error TooLittleReceivedError(uint256 minOut, uint256 out);

    /// @dev Modifier to check if the current block timestamp is before or equal to the deadline.
    modifier checkDeadline(uint256 deadline) {
        (_blockTimestamp() > deadline).revertError(ErrLib.ErrorCode.TOO_OLD_TRANSACTION);
        _;
    }

    function _blockTimestamp() internal view returns (uint256) {
        return block.timestamp;
    }

    constructor(
        address _underlyingPositionManagerAddress,
        address _underlyingQuoterV2,
        address _underlyingV3Factory,
        bytes32 _underlyingV3PoolInitCodeHash
    )
        LiquidityManager(
            _underlyingPositionManagerAddress,
            _underlyingQuoterV2,
            _underlyingV3Factory,
            _underlyingV3PoolInitCodeHash
        )
    {}

    /**
     * @dev Adds or removes a swap call to the whitelist.
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
        uint256[] memory amounts = new uint256[](tokens.length);
        for (uint256 i; i < tokens.length; ) {
            address token = tokens[i];
            uint256 amount = platformsFeesInfo[token] / Constants.COLLATERAL_BALANCE_PRECISION;
            if (amount > 0) {
                platformsFeesInfo[token] = 0;
                amounts[i] = amount;
                Vault(VAULT_ADDRESS).transferToken(token, recipient, amount);
            }
            unchecked {
                ++i;
            }
        }

        emit CollectProtocol(recipient, tokens, amounts);
    }

    /**
     * @notice This function is used to update the daily rate for holding a borrow position.
     * @dev Only the daily rate operator can call this function.
     * @param saleToken The address of the sale token.
     * @param holdToken The address of the hold token.
     * @param value The new value of the daily rate for the hold token.
     * @dev The value must be within the range of MIN_DAILY_RATE and MAX_DAILY_RATE.
     */
    function updateHoldTokenDailyRate(
        address saleToken,
        address holdToken,
        uint256 value
    ) external {
        (msg.sender != dailyRateOperator).revertError(ErrLib.ErrorCode.INVALID_CALLER);
        if (value > Constants.MAX_DAILY_RATE || value < Constants.MIN_DAILY_RATE) {
            revert InvalidSettingsValue(value);
        }
        (, TokenInfo storage holdTokenRateInfo) = _updateTokenRateInfo(saleToken, holdToken);
        holdTokenRateInfo.currentDailyRate = value;
        emit UpdateHoldTokenDailyRate(saleToken, holdToken, value);
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
     * @notice Retrieves the borrowing information for a specific tokenId.
     * @param tokenId The unique identifier of the PositionManager token.
     * @return extinfo An array of BorrowingInfoExt structs representing the borrowing information associated with the token.
     */
    function getLenderCreditsInfo(
        uint256 tokenId
    ) external view returns (BorrowingInfoExt[] memory extinfo) {
        bytes32[] memory borrowingKeys = tokenIdToBorrowingKeys[tokenId];
        extinfo = _getDebtsInfo(borrowingKeys);
    }

    /**
     * @notice Retrieves the debts information for a specific borrower.
     * @param borrower The address of the borrower.
     * @return extinfo An array of BorrowingInfoExt structs representing the borrowing information.
     */
    function getBorrowerDebtsInfo(
        address borrower
    ) external view returns (BorrowingInfoExt[] memory extinfo) {
        bytes32[] memory borrowingKeys = userBorrowingKeys[borrower];
        extinfo = _getDebtsInfo(borrowingKeys);
    }

    /**
     * @dev Returns the number of loans associated with a given token ID.
     * @param tokenId The ID of the token.
     * @return count The total number of loans associated with the token.
     */
    function getLenderCreditsCount(uint256 tokenId) external view returns (uint256 count) {
        bytes32[] memory borrowingKeys = tokenIdToBorrowingKeys[tokenId];
        count = borrowingKeys.length;
    }

    /**
     * @dev Returns the number of borrowings for a given borrower.
     * @param borrower The address of the borrower.
     * @return count The total number of borrowings for the borrower.
     */
    function getBorrowerDebtsCount(address borrower) external view returns (uint256 count) {
        bytes32[] memory borrowingKeys = userBorrowingKeys[borrower];
        count = borrowingKeys.length;
    }

    /**
     * @dev Returns the current daily rate for holding tokens.
     * @param saleToken The address of the token being sold.
     * @param holdToken The address of the token being held.
     * @return currentDailyRate The current daily rate for holding tokens.
     */
    function getHoldTokenDailyRateInfo(
        address saleToken,
        address holdToken
    ) external view returns (uint256 currentDailyRate, TokenInfo memory holdTokenRateInfo) {
        (currentDailyRate, holdTokenRateInfo) = _getHoldTokenRateInfo(saleToken, holdToken);
    }

    /**
     * @dev Returns the fees information for multiple tokens in an array.
     * @param tokens An array of token addresses for which the fees are to be retrieved.
     * @return fees An array containing the fees for each token.
     */
    function getPlatformsFeesInfo(
        address[] calldata tokens
    ) external view returns (uint256[] memory fees) {
        fees = new uint256[](tokens.length);
        for (uint256 i; i < tokens.length; ) {
            address token = tokens[i];
            uint256 amount = platformsFeesInfo[token] / Constants.COLLATERAL_BALANCE_PRECISION;
            fees[i] = amount;
            unchecked {
                ++i;
            }
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
        BorrowingInfo memory borrowing = borrowingsInfo[borrowingKey];
        if (borrowing.borrowedAmount > 0) {
            (uint256 currentDailyRate, ) = _getHoldTokenRateInfo(
                borrowing.saleToken,
                borrowing.holdToken
            );

            uint256 everySecond = (
                FullMath.mulDivRoundingUp(
                    borrowing.borrowedAmount,
                    currentDailyRate * Constants.COLLATERAL_BALANCE_PRECISION,
                    1 days * Constants.BP
                )
            );

            collateralAmt = FullMath.mulDivRoundingUp(
                everySecond,
                lifetimeInSeconds,
                Constants.COLLATERAL_BALANCE_PRECISION
            );

            if (collateralAmt == 0) collateralAmt = 1;
        }
    }

    /**
     * @notice This function is used to increase the daily rate collateral for a specific borrowing.
     * @param borrowingKey The unique identifier of the borrowing.
     * @param collateralAmt The amount of collateral to be added.
     */
    function increaseCollateralBalance(bytes32 borrowingKey, uint256 collateralAmt) external {
        BorrowingInfo storage borrowing = borrowingsInfo[borrowingKey];
        (borrowing.borrowedAmount == 0 || borrowing.borrower != address(msg.sender)).revertError(
            ErrLib.ErrorCode.INVALID_BORROWING_KEY
        );

        borrowing.dailyRateCollateralBalance +=
            collateralAmt *
            Constants.COLLATERAL_BALANCE_PRECISION;
        _pay(borrowing.holdToken, msg.sender, VAULT_ADDRESS, collateralAmt);
        emit IncreaseCollateralBalance(msg.sender, borrowingKey, collateralAmt);
    }

    /**
     * @notice Take over debt by transferring ownership of a borrowing to the current caller
     * @dev This function allows the current caller to take over a debt from another borrower.
     * The function validates the borrowingKey and checks if the collateral balance is negative.
     * If the conditions are met, the function transfers ownership of the borrowing to the current caller,
     * updates the daily rate collateral balance, and pays the collateral amount to the vault.
     * Emits a `TakeOverDebt` event.
     * @param borrowingKey The unique key associated with the borrowing to be taken over
     * @param collateralAmt The amount of collateral to be provided by the new borrower
     */
    function takeOverDebt(bytes32 borrowingKey, uint256 collateralAmt) external {
        BorrowingInfo memory oldBorrowing = borrowingsInfo[borrowingKey];
        (oldBorrowing.borrowedAmount == 0).revertError(ErrLib.ErrorCode.INVALID_BORROWING_KEY);

        uint256 accLoanRatePerSeconds;
        uint256 minPayment;
        {
            (, TokenInfo storage holdTokenRateInfo) = _updateTokenRateInfo(
                oldBorrowing.saleToken,
                oldBorrowing.holdToken
            );
            accLoanRatePerSeconds = holdTokenRateInfo.accLoanRatePerSeconds;
            (int256 collateralBalance, uint256 currentFees) = _calculateCollateralBalance(
                oldBorrowing.borrowedAmount,
                oldBorrowing.accLoanRatePerSeconds,
                oldBorrowing.dailyRateCollateralBalance,
                accLoanRatePerSeconds
            );

            (collateralBalance >= 0).revertError(ErrLib.ErrorCode.FORBIDDEN);
            currentFees = _pickUpPlatformFees(oldBorrowing.holdToken, currentFees);
            oldBorrowing.feesOwed += currentFees;

            minPayment = (uint256(-collateralBalance) / Constants.COLLATERAL_BALANCE_PRECISION) + 1;
            (collateralAmt <= minPayment).revertError(
                ErrLib.ErrorCode.COLLATERAL_AMOUNT_IS_NOT_ENOUGH
            );
        }

        LoanInfo[] memory oldLoans = loansInfo[borrowingKey];
        _removeKeysAndClearStorage(oldBorrowing.borrower, borrowingKey, oldLoans);

        (
            uint256 feesDebt,
            bytes32 newBorrowingKey,
            BorrowingInfo storage newBorrowing
        ) = _initBorrowing(oldBorrowing.saleToken, oldBorrowing.holdToken, accLoanRatePerSeconds);
        _addKeysAndLoansInfo(newBorrowing.borrowedAmount > 0, borrowingKey, oldLoans);

        newBorrowing.borrowedAmount += oldBorrowing.borrowedAmount;
        newBorrowing.liquidationBonus += oldBorrowing.liquidationBonus;
        newBorrowing.feesOwed += oldBorrowing.feesOwed;
        // oldBorrowing.dailyRateCollateralBalance is 0
        newBorrowing.dailyRateCollateralBalance +=
            (collateralAmt - minPayment) *
            Constants.COLLATERAL_BALANCE_PRECISION;
        //newBorrowing.accLoanRatePerSeconds = oldBorrowing.accLoanRatePerSeconds;
        _pay(oldBorrowing.holdToken, msg.sender, VAULT_ADDRESS, collateralAmt + feesDebt);
        emit TakeOverDebt(oldBorrowing.borrower, msg.sender, borrowingKey, newBorrowingKey);
    }

    /**
     * @notice Borrow function allows a user to borrow tokens by providing collateral and taking out loans.
     * @dev Emits a Borrow event upon successful borrowing.
     * @param params The BorrowParams struct containing the necessary parameters for borrowing.
     * @param deadline The deadline timestamp after which the transaction is considered invalid.
     */
    function borrow(
        BorrowParams calldata params,
        uint256 deadline
    ) external nonReentrant checkDeadline(deadline) {
        BorrowCache memory cache = _precalculateBorrowing(params);
        (uint256 feesDebt, bytes32 borrowingKey, BorrowingInfo storage borrowing) = _initBorrowing(
            params.saleToken,
            params.holdToken,
            cache.accLoanRatePerSeconds
        );
        _addKeysAndLoansInfo(borrowing.borrowedAmount > 0, borrowingKey, params.loans);

        uint256 liquidationBonus = getLiquidationBonus(
            params.holdToken,
            cache.borrowedAmount,
            params.loans.length
        );

        borrowing.borrowedAmount += cache.borrowedAmount;
        borrowing.liquidationBonus += liquidationBonus;
        borrowing.dailyRateCollateralBalance +=
            cache.dailyRateCollateral *
            Constants.COLLATERAL_BALANCE_PRECISION;

        uint256 borrowingCollateral = cache.borrowedAmount - cache.holdTokenBalance;
        (borrowingCollateral > params.maxCollateral).revertError(
            ErrLib.ErrorCode.TOO_BIG_COLLATERAL
        );

        // Transfer the required tokens to the VAULT_ADDRESS for collateral and holdTokenBalance
        _pay(
            params.holdToken,
            msg.sender,
            VAULT_ADDRESS,
            borrowingCollateral + liquidationBonus + cache.dailyRateCollateral + feesDebt
        );

        _pay(params.holdToken, address(this), VAULT_ADDRESS, cache.holdTokenBalance);
        // Emit the Borrow event with the borrower, borrowing key, and borrowed amount
        emit Borrow(
            msg.sender,
            borrowingKey,
            cache.borrowedAmount,
            borrowingCollateral,
            liquidationBonus,
            cache.dailyRateCollateral
        );
    }

    /**
     * @notice This function is used to repay a loan.
     * @param params The repayment parameters including
     *  activation of the emergency liquidity restoration mode (available only to the lender)
     *  internal swap pool fee,
     *  external swap parameters,
     *  borrowing key,
     *  swap slippage allowance.
     * @param deadline The deadline by which the repayment must be made.
     */
    function repay(
        RepayParams calldata params,
        uint256 deadline
    ) external nonReentrant checkDeadline(deadline) {
        BorrowingInfo memory borrowing = borrowingsInfo[params.borrowingKey];
        (borrowing.borrowedAmount == 0).revertError(ErrLib.ErrorCode.INVALID_BORROWING_KEY);

        bool zeroForSaleToken = borrowing.saleToken < borrowing.holdToken;
        uint256 liquidationBonus = borrowing.liquidationBonus;
        int256 collateralBalance;
        (, TokenInfo storage holdTokenRateInfo) = _updateTokenRateInfo(
            borrowing.saleToken,
            borrowing.holdToken
        );
        {
            // Calculate collateral balance and validate caller
            //int256 collateralBalance;

            uint256 accLoanRatePerSeconds = holdTokenRateInfo.accLoanRatePerSeconds;
            uint256 currentFees;
            (collateralBalance, currentFees) = _calculateCollateralBalance(
                borrowing.borrowedAmount,
                borrowing.accLoanRatePerSeconds,
                borrowing.dailyRateCollateralBalance,
                accLoanRatePerSeconds
            );

            (msg.sender != borrowing.borrower && collateralBalance >= 0).revertError(
                ErrLib.ErrorCode.INVALID_CALLER
            );

            // Calculate liquidation bonus and adjust fees owed

            if (
                collateralBalance > 0 &&
                (currentFees + borrowing.feesOwed) / Constants.COLLATERAL_BALANCE_PRECISION >
                Constants.MINIMUM_FEES_AMOUNT
            ) {
                liquidationBonus +=
                    uint256(collateralBalance) /
                    Constants.COLLATERAL_BALANCE_PRECISION;
            } else {
                currentFees = borrowing.dailyRateCollateralBalance;
            }

            // Calculate platform fees and adjust fees owed
            borrowing.feesOwed += _pickUpPlatformFees(borrowing.holdToken, currentFees);
        }
        if (params.isEmergency) {
            (collateralBalance >= 0).revertError(ErrLib.ErrorCode.FORBIDDEN);
            (
                uint256 removedAmt,
                uint256 feesAmt,
                uint256 loansInfoLength
            ) = _calculateEmergencyLoanClosure(
                    zeroForSaleToken,
                    params.borrowingKey,
                    borrowing.feesOwed,
                    borrowing.borrowedAmount
                );
            (removedAmt == 0).revertError(ErrLib.ErrorCode.LIQUIDITY_IS_ZERO);
            // prevent overspent
            borrowing.borrowedAmount -= removedAmt;
            borrowing.feesOwed -= feesAmt;
            feesAmt /= Constants.COLLATERAL_BALANCE_PRECISION;

            holdTokenRateInfo.totalBorrowed -= removedAmt;

            if (loansInfoLength == 0) {
                LoanInfo[] memory empty;
                _removeKeysAndClearStorage(borrowing.borrower, params.borrowingKey, empty);
                feesAmt += liquidationBonus;
            } else {
                BorrowingInfo storage borrowingStorage = borrowingsInfo[params.borrowingKey];
                borrowingStorage.dailyRateCollateralBalance = 0;
                borrowingStorage.feesOwed = borrowing.feesOwed;
                borrowingStorage.borrowedAmount = borrowing.borrowedAmount;
                borrowingStorage.accLoanRatePerSeconds =
                    holdTokenRateInfo.accLoanRatePerSeconds -
                    FullMath.mulDiv(
                        uint256(-collateralBalance),
                        Constants.BP,
                        borrowing.borrowedAmount // new amount
                    );
            }

            Vault(VAULT_ADDRESS).transferToken(
                borrowing.holdToken,
                msg.sender,
                removedAmt + feesAmt
            );
            emit EmergencyLoanClosure(borrowing.borrower, msg.sender, params.borrowingKey);
        } else {
            holdTokenRateInfo.totalBorrowed -= borrowing.borrowedAmount;

            // Transfer borrowed tokens from VAULT to contract
            Vault(VAULT_ADDRESS).transferToken(
                borrowing.holdToken,
                address(this),
                borrowing.borrowedAmount + liquidationBonus
            );
            // Restore liquidity using borrowed amount and pay a daily rate fees
            LoanInfo[] memory loans = loansInfo[params.borrowingKey];
            _maxApproveIfNecessary(
                borrowing.holdToken,
                address(underlyingPositionManager),
                type(uint128).max
            );
            _maxApproveIfNecessary(
                borrowing.saleToken,
                address(underlyingPositionManager),
                type(uint128).max
            );

            _restoreLiquidity(
                RestoreLiquidityParams({
                    zeroForSaleToken: zeroForSaleToken,
                    fee: params.internalSwapPoolfee,
                    slippageBP1000: params.swapSlippageBP1000,
                    totalfeesOwed: borrowing.feesOwed,
                    totalBorrowedAmount: borrowing.borrowedAmount
                }),
                params.externalSwap,
                loans
            );

            (uint256 saleTokenBalance, uint256 holdTokenBalance) = _getPairBalance(
                borrowing.saleToken,
                borrowing.holdToken
            );
            // Remove borrowing key from related data structures
            _removeKeysAndClearStorage(borrowing.borrower, params.borrowingKey, loans);
            // Pay a profit to a msg.sender
            _pay(borrowing.holdToken, address(this), msg.sender, holdTokenBalance);
            _pay(borrowing.saleToken, address(this), msg.sender, saleTokenBalance);

            emit Repay(borrowing.borrower, msg.sender, params.borrowingKey);
        }
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
        uint256[2] memory bonus = specificTokenLiquidationBonus[token];
        uint256 minimumBonus;
        if (bonus[0] == 0) {
            bonus = dafaultLiquidationBonusBP;
            uint8 decimals = IERC20Metadata(token).decimals();
            minimumBonus = bonus[1] * (10 ** decimals);
        } else {
            minimumBonus = bonus[1];
        }
        liquidationBonus = FullMath.mulDiv(borrowedAmount, bonus[0] * times, Constants.BP);
        if (liquidationBonus < minimumBonus) {
            liquidationBonus = minimumBonus;
        }
    }

    /**
     * @notice Calculates the amount to be repaid in an emergency situation.
     * @dev This function removes loans associated with a borrowing key owned by the `msg.sender`.
     * @param zeroForSaleToken A boolean value indicating whether the token for sale is the 0th token or not.
     * @param borrowingKey The identifier for the borrowing key.
     * @param totalfeesOwed The total fees owed without pending fees.
     * @param totalBorrowedAmount The total borrowed amount.
     * @return removedAmt The amount of debt removed from the loan.
     * @return feesAmt The calculated fees amount.
     * @return loansInfoLength The length of the `loansInfo` array after removal.
     */
    function _calculateEmergencyLoanClosure(
        bool zeroForSaleToken,
        bytes32 borrowingKey,
        uint256 totalfeesOwed,
        uint256 totalBorrowedAmount
    ) private returns (uint256 removedAmt, uint256 feesAmt, uint256 loansInfoLength) {
        RestoreLiquidityCache memory cache;
        LoanInfo[] storage loans = loansInfo[borrowingKey];
        for (uint256 i; i < loans.length; ) {
            LoanInfo memory loan = loans[i];
            address creditor = underlyingPositionManager.ownerOf(loan.tokenId);
            if (creditor == msg.sender) {
                loans[i] = loans[loans.length - 1];
                loans.pop();
                tokenIdToBorrowingKeys[loan.tokenId].removeKey(borrowingKey);
                _upRestoreLiquidityCache(zeroForSaleToken, loan, cache);
                removedAmt += cache.holdTokenDebt;
                feesAmt += FullMath.mulDiv(totalfeesOwed, cache.holdTokenDebt, totalBorrowedAmount);
            } else {
                unchecked {
                    ++i;
                }
            }
        }
        loansInfoLength = loans.length;
    }

    function _removeKeysAndClearStorage(
        address borrower,
        bytes32 borrowingKey,
        LoanInfo[] memory loans
    ) private {
        // Remove borrowing key from related data structures
        for (uint256 i; i < loans.length; ) {
            tokenIdToBorrowingKeys[loans[i].tokenId].removeKey(borrowingKey);
            unchecked {
                ++i;
            }
        }
        userBorrowingKeys[borrower].removeKey(borrowingKey);
        // Delete borrowing information
        delete borrowingsInfo[borrowingKey];
        delete loansInfo[borrowingKey];
    }

    function _addKeysAndLoansInfo(
        bool update,
        bytes32 borrowingKey,
        LoanInfo[] memory sourceLoans
    ) private {
        LoanInfo[] storage loans = loansInfo[borrowingKey];
        for (uint256 i; i < sourceLoans.length; ) {
            LoanInfo memory loan = sourceLoans[i];
            bytes32[] storage tokenIdLoansKeys = tokenIdToBorrowingKeys[loan.tokenId];
            update
                ? tokenIdLoansKeys.addKeyIfNotExists(borrowingKey)
                : tokenIdLoansKeys.push(borrowingKey);
            loans.push(loan);
            unchecked {
                ++i;
            }
        }
        // Ensure that the number of loans does not exceed the maximum limit
        (loans.length > Constants.MAX_NUM_LOANS_PER_POSITION).revertError(
            ErrLib.ErrorCode.TOO_MANY_LOANS_PER_POSITION
        );
        if (!update) {
            // If it's a new position, ensure that the user does not have too many positions
            bytes32[] storage allUserBorrowingKeys = userBorrowingKeys[msg.sender];
            (allUserBorrowingKeys.length > Constants.MAX_NUM_USER_POSOTION).revertError(
                ErrLib.ErrorCode.TOO_MANY_USER_POSITIONS
            );
            // Add the borrowingKey to the user's borrowing keys
            allUserBorrowingKeys.push(borrowingKey);
        }
    }

    function _precalculateBorrowing(
        BorrowParams calldata params
    ) private returns (BorrowCache memory cache) {
        {
            bool zeroForSaleToken = params.saleToken < params.holdToken;
            TokenInfo storage holdTokenRateInfo;
            // Update the token rate information and retrieve the dailyRate and TokenInfo for the holdTokenRateInfo
            (cache.dailyRateCollateral, holdTokenRateInfo) = _updateTokenRateInfo(
                params.saleToken,
                params.holdToken
            );

            cache.accLoanRatePerSeconds = holdTokenRateInfo.accLoanRatePerSeconds;
            // Extract liquidity
            cache.borrowedAmount = _extractLiquidity(
                zeroForSaleToken,
                params.saleToken,
                params.holdToken,
                params.loans
            );

            holdTokenRateInfo.totalBorrowed += cache.borrowedAmount;
        }

        cache.dailyRateCollateral = FullMath.mulDivRoundingUp(
            cache.borrowedAmount,
            cache.dailyRateCollateral,
            Constants.BP
        ); //prepayment per day fees

        if (cache.dailyRateCollateral < Constants.MINIMUM_FEES_AMOUNT) {
            cache.dailyRateCollateral = Constants.MINIMUM_FEES_AMOUNT;
        }
        uint256 saleTokenBalance;

        (saleTokenBalance, cache.holdTokenBalance) = _getPairBalance(
            params.saleToken,
            params.holdToken
        );
        if (saleTokenBalance > 0) {
            if (params.externalSwap.swapTarget != address(0)) {
                cache.holdTokenBalance += _patchAmountsAndCallSwap(
                    params.saleToken,
                    params.holdToken,
                    params.externalSwap,
                    saleTokenBalance,
                    0
                );
            } else {
                cache.holdTokenBalance += _v3SwapExactInput(
                    v3SwapExactInputParams({
                        fee: params.internalSwapPoolfee,
                        tokenIn: params.saleToken,
                        tokenOut: params.holdToken,
                        amountIn: saleTokenBalance,
                        amountOutMinimum: 0
                    })
                );
            }
        }

        // Ensure that the received holdToken balance meets the minimum required
        if (cache.holdTokenBalance < params.minHoldTokenOut) {
            revert TooLittleReceivedError(params.minHoldTokenOut, cache.holdTokenBalance);
        }
    }

    function _initBorrowing(
        address saleToken,
        address holdToken,
        uint256 accLoanRatePerSeconds
    ) private returns (uint256 feesDebt, bytes32 borrowingKey, BorrowingInfo storage borrowing) {
        borrowingKey = Keys.computeBorrowingKey(msg.sender, saleToken, holdToken);
        borrowing = borrowingsInfo[borrowingKey];

        if (borrowing.borrowedAmount > 0) {
            (borrowing.borrower != address(msg.sender)).revertError(
                ErrLib.ErrorCode.INVALID_BORROWING_KEY
            );
            (int256 collateralBalance, uint256 currentFees) = _calculateCollateralBalance(
                borrowing.borrowedAmount,
                borrowing.accLoanRatePerSeconds,
                borrowing.dailyRateCollateralBalance,
                accLoanRatePerSeconds
            );

            if (collateralBalance < 0) {
                feesDebt = uint256(-collateralBalance) / Constants.COLLATERAL_BALANCE_PRECISION + 1;
                borrowing.dailyRateCollateralBalance = 0;
            } else {
                borrowing.dailyRateCollateralBalance -= currentFees;
            }

            currentFees = _pickUpPlatformFees(holdToken, currentFees);
            borrowing.feesOwed += currentFees;
        } else {
            // Initialize the BorrowingInfo for the new position
            borrowing.borrower = msg.sender;
            borrowing.saleToken = saleToken;
            borrowing.holdToken = holdToken;
        }
        borrowing.accLoanRatePerSeconds = accLoanRatePerSeconds;
    }

    function _pickUpPlatformFees(
        address holdToken,
        uint256 fees
    ) private returns (uint256 currentFees) {
        uint256 platformFees = (fees * platformFeesBP) / Constants.BP;
        platformsFeesInfo[holdToken] += platformFees;
        currentFees = fees - platformFees;
    }

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
        borrowing = borrowingsInfo[borrowingKey];
        (uint256 currentDailyRate, TokenInfo memory holdTokenRateInfo) = _getHoldTokenRateInfo(
            borrowing.saleToken,
            borrowing.holdToken
        );

        (collateralBalance, ) = _calculateCollateralBalance(
            borrowing.borrowedAmount,
            borrowing.accLoanRatePerSeconds,
            borrowing.dailyRateCollateralBalance,
            holdTokenRateInfo.accLoanRatePerSeconds
        );

        if (collateralBalance > 0) {
            uint256 everySecond = (
                FullMath.mulDivRoundingUp(
                    borrowing.borrowedAmount,
                    currentDailyRate * Constants.COLLATERAL_BALANCE_PRECISION,
                    1 days * Constants.BP
                )
            );

            estimatedLifeTime = uint256(collateralBalance) / everySecond;
            if (estimatedLifeTime == 0) estimatedLifeTime = 1;
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
}
