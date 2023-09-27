// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@uniswap/v3-core/contracts/libraries/FixedPoint128.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./abstract/LiquidityManager.sol";
import "./abstract/OwnerSettings.sol";
import "./abstract/DailyRateAndCollateral.sol";

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
    using { Keys.toUInt256 } for bool;
    using { Keys.removeKey, Keys.addKeyIfNotExists } for bytes32[];

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
        /// @notice An array of Loan structs representing multiple loans
        Loan[] loans;
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
        Loan[] loans;
    }
    /// @notice This struct used for caching variables inside a function 'borrow'
    struct BorrowCache {
        bool zeroForSaleToken;
        uint256 dailyRate;
        uint256 accLoanRatePerSeconds;
        uint256 borrowedAmount;
        uint256 holdTokenBalance;
        uint256 saleTokenBalance;
    }
    /// @notice Struct representing the extended borrowing information.
    struct BorrowingInfoExt {
        /// @notice The main borrowing information.
        BorrowingInfo info;
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

    /// borrowingKey=>BorrowingInfo
    mapping(bytes32 => BorrowingInfo) public borrowings;
    /// borrower => BorrowingKeys[]
    mapping(address => bytes32[]) public userBorrowingKeys;
    /// tokenId => BorrowingKeys[]
    mapping(uint256 => bytes32[]) public underlyingPosBorrowingKeys;

    ///  token => FeesAmt
    mapping(address => uint256) public platformsFeesInfo;

    event Borrow(
        address borrower,
        bytes32 borrowingKey,
        uint256 borrowedAmount,
        uint256 borrowingCollateral,
        uint256 liquidationBonus,
        uint256 dailyRatePrepayment
    );

    event Repay(address borrower, address liquidator, bytes32 borrowingKey);
    event CollectProtocol(address recipient, address[] tokens, uint256[] amounts);
    event UpdateHoldTokenDailyRate(address saleToken, address holdToken, uint256 value);
    event IncreaseCollateralBalance(address borrower, bytes32 borrowingKey, uint256 collateralAmt);

    /// @dev Modifier to check if the current block timestamp is before or equal to the deadline.
    modifier checkDeadline(uint256 deadline) {
        require(_blockTimestamp() <= deadline, "Transaction too old");
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
        require(
            swapTarget != VAULT_ADDRESS &&
                swapTarget != address(this) &&
                swapTarget != address(underlyingPositionManager),
            "forbidden target"
        );
        require(funcSelector != IERC20.transferFrom.selector, "forbidden selector");
        whitelistedCall[swapTarget][funcSelector] = isAllowed;
    }

    /**
     * @notice This function allows the owner to collect protocol fees for multiple tokens and transfer them to a specified recipient.
     * @dev Only the contract owner can call this function.
     * @param recipient The address of the recipient who will receive the collected fees.
     * @param tokens An array of addresses representing the tokens for which fees will be collected.
     */
    function collectProtocol(address recipient, address[] memory tokens) external onlyOwner {
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
        require(msg.sender == dailyRateOperator, "invalid caller");
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
    }

    /**
     * @notice Retrieves the loans information for a specific lender.
     * @param tokenId The unique identifier of the token representing the lender.
     * @return extinfo An array of BorrowingInfoExt structs representing the borrowing information.
     */
    function getLenderLoansInfo(
        uint256 tokenId
    ) external view returns (BorrowingInfoExt[] memory extinfo) {
        bytes32[] memory borrowingKeys = underlyingPosBorrowingKeys[tokenId];
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
    function getLoansCount(uint256 tokenId) external view returns (uint256 count) {
        bytes32[] memory borrowingKeys = underlyingPosBorrowingKeys[tokenId];
        count = borrowingKeys.length;
    }

    /**
     * @dev Returns the number of borrowings for a given borrower.
     * @param borrower The address of the borrower.
     * @return count The total number of borrowings for the borrower.
     */
    function getBorrowingsCount(address borrower) external view returns (uint256 count) {
        bytes32[] memory borrowingKeys = userBorrowingKeys[borrower];
        count = borrowingKeys.length;
    }

    /**
     * @dev Returns the current daily rate for holding tokens.
     * @param saleToken The address of the token being sold.
     * @param holdToken The address of the token being held.
     * @return currentDailyRate The current daily rate for holding tokens.
     */
    function getHoldTokenDailyRate(
        address saleToken,
        address holdToken
    ) external view returns (uint256 currentDailyRate) {
        (currentDailyRate, ) = _getHoldTokenRateInfo(saleToken, holdToken);
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
        BorrowingInfo memory borrowing = borrowings[borrowingKey];
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
        BorrowingInfo storage borrowing = borrowings[borrowingKey];
        require(
            borrowing.borrowedAmount > 0 && borrowing.borrower == address(msg.sender),
            "invalid borrowingKey"
        );
        borrowing.dailyRateCollateralBalance +=
            collateralAmt *
            Constants.COLLATERAL_BALANCE_PRECISION;
        _pay(borrowing.holdToken, msg.sender, VAULT_ADDRESS, collateralAmt);
        emit IncreaseCollateralBalance(msg.sender, borrowingKey, collateralAmt);
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
        BorrowCache memory cache;

        cache.zeroForSaleToken = params.saleToken < params.holdToken;
        TokenInfo storage holdTokenRateInfo;
        // Update the token rate information and retrieve the dailyRate and TokenInfo for the holdTokenRateInfo
        (cache.dailyRate, holdTokenRateInfo) = _updateTokenRateInfo(
            params.saleToken,
            params.holdToken
        );
        cache.accLoanRatePerSeconds = holdTokenRateInfo.accLoanRatePerSeconds;
        // Extract liquidity
        cache.borrowedAmount = _extractLiquidity(
            cache.zeroForSaleToken,
            params.saleToken,
            params.holdToken,
            params.loans
        );
        require(
            cache.borrowedAmount >= Constants.MINIMUM_BORROWED_AMOUNT,
            "too little borrowed amount"
        );

        (cache.saleTokenBalance, cache.holdTokenBalance) = _getPairBalance(
            params.saleToken,
            params.holdToken
        );

        // If there are saleToken balances available, perform a swap to get more holdToken
        if (cache.saleTokenBalance > 0) {
            if (params.externalSwap.swapTarget != address(0)) {
                cache.holdTokenBalance += _patchAmountsAndCallSwap(
                    params.saleToken,
                    params.holdToken,
                    params.externalSwap,
                    cache.saleTokenBalance,
                    0
                );
            } else {
                cache.holdTokenBalance += _v3SwapExactInput(
                    v3SwapExactInputParams({
                        fee: params.internalSwapPoolfee,
                        tokenIn: params.saleToken,
                        tokenOut: params.holdToken,
                        amountIn: cache.saleTokenBalance,
                        amountOutMinimum: 0
                    })
                );
            }
        }

        // Ensure that the received holdToken balance meets the minimum required

        require(cache.holdTokenBalance >= params.minHoldTokenOut, "too little received");

        bytes32 borrowingKey = Keys.computeBorrowingKey(
            msg.sender,
            params.saleToken,
            params.holdToken
        );
        BorrowingInfo storage borrowing = borrowings[borrowingKey];

        if (borrowing.borrowedAmount > 0) {
            (int256 collateralBalance, uint256 currentFees) = _calculateCollateralBalance(
                borrowing.borrowedAmount,
                borrowing.accLoanRatePerSeconds,
                borrowing.dailyRateCollateralBalance,
                cache.accLoanRatePerSeconds
            );
            // Check if the collateral meets the required amount of fees
            require(collateralBalance > 0, "collateral increase required");
            // Calculate the platformFees and deduct from the dailyRateCollateralBalance
            uint256 platformFees = (currentFees * platformFeesBP) / Constants.BP;
            currentFees -= platformFees;
            platformsFeesInfo[params.holdToken] += platformFees;
            borrowing.dailyRateCollateralBalance -= currentFees;
            borrowing.feesOwed += currentFees;
        } else {
            // If it's a new position, ensure that the user does not have too many positions
            bytes32[] storage allUserBorrowingKeys = userBorrowingKeys[msg.sender];
            require(
                allUserBorrowingKeys.length < Constants.MAX_NUM_USER_POSOTION,
                "too many positions"
            );
            // Add the borrowingKey to the user's borrowing keys
            allUserBorrowingKeys.push(borrowingKey);
            // Initialize the BorrowingInfo for the new position
            borrowing.borrower = msg.sender;
            borrowing.saleToken = params.saleToken;
            borrowing.holdToken = params.holdToken;
        }
        // Iterate through the loans and add them to the borrowing struct
        for (uint256 i; i < params.loans.length; ) {
            bytes32[] storage allUnderlyingPosBorrowingKeys = underlyingPosBorrowingKeys[
                params.loans[i].tokenId
            ];
            allUnderlyingPosBorrowingKeys.addKeyIfNotExists(borrowingKey);
            borrowing.loans.push(params.loans[i]);
            unchecked {
                ++i;
            }
        }
        // Ensure that the number of loans does not exceed the maximum limit
        require(borrowing.loans.length < Constants.MAX_NUM_LOANS_PER_POSITION, "too many loans");

        borrowing.accLoanRatePerSeconds = cache.accLoanRatePerSeconds;

        uint256 liquidationBonus = specificTokenLiquidationBonus[params.holdToken];
        liquidationBonus = FullMath.mulDiv(
            cache.borrowedAmount,
            (liquidationBonus > 0 ? liquidationBonus : dafaultLiquidationBonusBP) *
                params.loans.length,
            Constants.BP
        );

        cache.dailyRate = FullMath.mulDivRoundingUp(
            cache.borrowedAmount,
            cache.dailyRate,
            Constants.BP
        ); //prepayment per day fees

        if (cache.dailyRate < Constants.MINIMUM_FEES_AMOUNT) {
            cache.dailyRate = Constants.MINIMUM_FEES_AMOUNT;
        }

        borrowing.borrowedAmount += cache.borrowedAmount;
        borrowing.liquidationBonus += liquidationBonus;
        borrowing.dailyRateCollateralBalance +=
            cache.dailyRate *
            Constants.COLLATERAL_BALANCE_PRECISION;

        uint256 borrowingCollateral = cache.borrowedAmount - cache.holdTokenBalance;
        require(borrowingCollateral <= params.maxCollateral, "too much borrowing collateral");
        holdTokenRateInfo.totalBorrowed += cache.borrowedAmount;
        // Transfer the required tokens to the VAULT_ADDRESS for collateral and holdTokenBalance
        _pay(
            params.holdToken,
            msg.sender,
            VAULT_ADDRESS,
            borrowingCollateral + liquidationBonus + cache.dailyRate
        );
        // console.log("leverage =", cache.holdTokenBalance / collateral);
        // console.log(
        //     "leverage (with liquidationBonus + dailyRate)=",
        //     cache.holdTokenBalance / (collateral + liquidationBonus + cache.dailyRate)
        // );
        _pay(params.holdToken, address(this), VAULT_ADDRESS, cache.holdTokenBalance);
        // Emit the Borrow event with the borrower, borrowing key, and borrowed amount
        emit Borrow(
            msg.sender,
            borrowingKey,
            cache.borrowedAmount,
            borrowingCollateral,
            liquidationBonus,
            cache.dailyRate
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
        BorrowingInfo memory borrowing = borrowings[params.borrowingKey];
        require(borrowing.borrowedAmount > 0, "invalid borrowingKey");

        bool zeroForSaleToken = borrowing.saleToken < borrowing.holdToken;
        uint256 feesOwed = borrowing.dailyRateCollateralBalance;
        (, TokenInfo storage holdTokenRateInfo) = _updateTokenRateInfo(
            borrowing.saleToken,
            borrowing.holdToken
        );
        {
            // Calculate collateral balance and validate caller
            int256 collateralBalance;
            {
                uint256 accLoanRatePerSeconds = holdTokenRateInfo.accLoanRatePerSeconds;

                (collateralBalance, ) = _calculateCollateralBalance(
                    borrowing.borrowedAmount,
                    borrowing.accLoanRatePerSeconds,
                    borrowing.dailyRateCollateralBalance,
                    accLoanRatePerSeconds
                );
                require(
                    msg.sender == borrowing.borrower || collateralBalance < 0,
                    "invalid caller"
                );
            }
            // Calculate liquidation bonus and adjust fees owed
            {
                uint256 liquidationBonus = borrowing.liquidationBonus;
                if (
                    collateralBalance > 0 &&
                    (feesOwed + borrowing.feesOwed - uint256(collateralBalance)) /
                        Constants.COLLATERAL_BALANCE_PRECISION >
                    Constants.MINIMUM_FEES_AMOUNT
                ) {
                    //??
                    feesOwed -= uint256(collateralBalance);
                    liquidationBonus +=
                        uint256(collateralBalance) /
                        Constants.COLLATERAL_BALANCE_PRECISION;
                }
                // Transfer liquidation bonus and remaining collateral to msg.sender
                // For liquidators, the balance of the collateral is always zero
                Vault(VAULT_ADDRESS).transferToken(
                    borrowing.holdToken,
                    msg.sender,
                    liquidationBonus
                );
            }
            // Calculate platform fees and adjust fees owed
            {
                uint256 platformFees = (feesOwed * platformFeesBP) / Constants.BP;
                platformsFeesInfo[borrowing.holdToken] += platformFees;
                feesOwed -= platformFees;
            }
        }

        feesOwed += borrowing.feesOwed;
        // Transfer borrowed tokens from VAULT to contract
        Vault(VAULT_ADDRESS).transferToken(
            borrowing.holdToken,
            address(this),
            borrowing.borrowedAmount
        );
        // Restore liquidity using borrowed amount and pay a daily rate fees
        Loan[] memory loans = borrowing.loans;
        _maxApproveIfNecessary(
            borrowing.holdToken,
            address(underlyingPositionManager),
            type(uint256).max / 2
        );
        _maxApproveIfNecessary(
            borrowing.saleToken,
            address(underlyingPositionManager),
            type(uint256).max / 2
        );

        _restoreLiquidity(
            RestoreLiquidityParams({
                isEmergency: params.isEmergency,
                zeroForSaleToken: zeroForSaleToken,
                fee: params.internalSwapPoolfee,
                slippageBP1000: params.swapSlippageBP1000,
                totalfeesOwed: feesOwed,
                totalBorrowedAmount: borrowing.borrowedAmount
            }),
            params.externalSwap,
            loans
        );
        holdTokenRateInfo.totalBorrowed -= borrowing.borrowedAmount;
        (uint256 saleTokenBalance, uint256 holdTokenBalance) = _getPairBalance(
            borrowing.saleToken,
            borrowing.holdToken
        );
        // Remove borrowing key from related data structures
        for (uint256 i; i < loans.length; ) {
            underlyingPosBorrowingKeys[loans[i].tokenId].removeKey(params.borrowingKey);
            unchecked {
                ++i;
            }
        }
        userBorrowingKeys[msg.sender].removeKey(params.borrowingKey);
        // Delete borrowing information
        delete borrowings[params.borrowingKey];
        // Pay a profit to a borrower
        _pay(borrowing.holdToken, address(this), msg.sender, holdTokenBalance);
        _pay(borrowing.saleToken, address(this), msg.sender, saleTokenBalance);

        emit Repay(borrowing.borrower, msg.sender, params.borrowingKey);
    }

    function _getDebtInfo(
        bytes32 borrowingKey
    )
        internal
        view
        returns (
            BorrowingInfo memory borrowing,
            int256 collateralBalance,
            uint256 estimatedLifeTime
        )
    {
        borrowing = borrowings[borrowingKey];
        (uint256 currentDailyRate, uint256 accLoanRatePerSeconds) = _getHoldTokenRateInfo(
            borrowing.saleToken,
            borrowing.holdToken
        );
        (collateralBalance, ) = _calculateCollateralBalance(
            borrowing.borrowedAmount,
            borrowing.accLoanRatePerSeconds,
            borrowing.dailyRateCollateralBalance,
            accLoanRatePerSeconds
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
    ) internal view returns (BorrowingInfoExt[] memory extinfo) {
        extinfo = new BorrowingInfoExt[](borrowingKeys.length);
        for (uint256 i; i < borrowingKeys.length; ) {
            extinfo[i].key = borrowingKeys[i];
            (
                extinfo[i].info,
                extinfo[i].collateralBalance,
                extinfo[i].estimatedLifeTime
            ) = _getDebtInfo(extinfo[i].key);
            unchecked {
                ++i;
            }
        }
    }
}
