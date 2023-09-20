// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@uniswap/v3-core/contracts/libraries/FixedPoint128.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./abstract/LiquidityManager.sol";
import "./abstract/OwnerSettings.sol";
import "./abstract/DailyRateAndCollateral.sol";
import "./libraries/ExternalCall.sol";

import "hardhat/console.sol";

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
    using Keys for bytes32[];
    using { ExternalCall._patchAmountAndCall } for address;
    using { ExternalCall._readFirstBytes4 } for bytes;

    struct SwapParams {
        /// Aggregator's router address
        address swapTarget;
        uint256 swapAmountInDataIndex;
        uint256 swapAmountOutMinimumDataIndex;
        uint256 maxGasForCall;
        /// Aggregator's data that stores pathes and amounts swap through
        bytes swapData;
    }

    /// @title BorrowParams
    /// @notice This struct represents the parameters required for borrowing.
    struct BorrowParams {
        uint24 swapPoolfee;
        address saleToken;
        address holdToken;
        uint256 minHoldTokenOut;
        uint256 maxCollateral;
        SwapParams externalSwap;
        Loan[] loans;
    }
    /// @title BorrowingInfo
    /// @notice This struct represents the borrowing information for a borrower.
    struct BorrowingInfo {
        address borrower;
        address saleToken;
        address holdToken;
        uint256 feesOwed;
        uint256 borrowedAmount;
        uint256 liquidationBonus;
        uint256 accLoanRatePerShare;
        uint256 dailyRateCollateral;
        Loan[] loans;
    }

    /// borrowingKey=>BorrowingInfo
    mapping(bytes32 => BorrowingInfo) public borrowings;
    /// borrower => BorrowingKeys[]
    mapping(address => bytes32[]) public userBorrowingKeys;
    /// tokenId => BorrowingKeys[]
    mapping(uint256 => bytes32[]) public underlyingPosBorrowingKeys;
    ///     swapTarget   => (func.selector => is allowed)
    mapping(address => mapping(bytes4 => bool)) public whitelistedCall;

    ///  token => Amt
    mapping(address => uint256) public platformsFeesInfo;

    event Borrow(address borrower, bytes32 borrowingKey, uint256 borrowedAmount);
    event Repay(address borrower, address liquidator, bytes32 borrowingKey);
    event CollectProtocol(address recipient, address[] tokens, uint256[] amounts);

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

    modifier checkDeadline(uint256 deadline) {
        require(_blockTimestamp() <= deadline, "Transaction too old");
        _;
    }

    modifier checkSwapCallParameters(address swapTarget, bytes calldata swapData) {
        require(
            swapTarget == address(0) || _checkSwapCallParameters(swapTarget, swapData),
            "swap call params is not supported"
        );
        _;
    }

    function _blockTimestamp() internal view returns (uint256) {
        return block.timestamp;
    }

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
        require(funcSelector != IERC20.transferFrom.selector, "forbidden function selector");
        whitelistedCall[swapTarget][funcSelector] = isAllowed;
    }

    function _checkSwapCallParameters(
        address swapTarget,
        bytes calldata swapData
    ) internal view returns (bool isAllowed) {
        bytes4 funcSelector = swapData._readFirstBytes4();
        isAllowed = whitelistedCall[swapTarget][funcSelector];
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
            uint256 amount = platformsFeesInfo[token];
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
        TokenInfo storage holdTokenRateInfo = saleToken < holdToken
            ? tokenPairs[Keys.computePairKey(saleToken, holdToken)][1]
            : tokenPairs[Keys.computePairKey(holdToken, saleToken)][0];
        _updateTokenRateInfo(holdTokenRateInfo);
        holdTokenRateInfo.currentDailyRate = value;
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
        BorrowingInfo memory borrowing = borrowings[borrowingKey];
        (uint256 currentDailyRate, uint256 accLoanRatePerShare) = _getHoldTokenRateInfo(
            borrowing.saleToken,
            borrowing.holdToken
        );
        balance = _checkDailyRateCollateral(
            borrowing.borrowedAmount,
            borrowing.accLoanRatePerShare,
            borrowing.dailyRateCollateral,
            accLoanRatePerShare
        );
        if (balance > 0) {
            uint256 everySecond = ((borrowing.borrowedAmount * currentDailyRate) / Constants.BP) /
                1 days;
            estimatedLifeTime = uint256(balance) / everySecond;
        }
    }

    /**
     * @notice This function is used to increase the daily rate collateral for a specific borrowing.
     * @param borrower The address of the borrower.
     * @param saleToken The address of the token being sold in the borrowing.
     * @param holdToken The address of the token being held as collateral.
     * @param collateralAmt The amount of collateral to be added.
     */
    function increaseDailyRateCollateral(
        address borrower,
        address saleToken,
        address holdToken,
        uint256 collateralAmt
    ) external {
        bytes32 borrowingKey = Keys.computeBorrowingKey(borrower, saleToken, holdToken);
        BorrowingInfo storage borrowing = borrowings[borrowingKey];
        require(borrowing.borrowedAmount > 0, "invalid position");
        borrowing.dailyRateCollateral += collateralAmt;
        _pay(holdToken, msg.sender, VAULT_ADDRESS, collateralAmt);
    }

    struct BorrowCache {
        bool zeroForSaleToken;
        uint256 dailyRate;
        uint256 accLoanRatePerShare;
        uint256 borrowedAmount;
        uint256 holdTokenBalance;
        uint256 saleTokenBalance;
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
    )
        external
        nonReentrant
        checkDeadline(deadline)
        checkSwapCallParameters(params.externalSwap.swapTarget, params.externalSwap.swapData)
    {
        BorrowCache memory cache;

        cache.zeroForSaleToken = params.saleToken < params.holdToken;
        // Retrieve the TokenInfo for the holdTokenRateInfo based on the ordering of saleToken and holdToken
        TokenInfo storage holdTokenRateInfo = cache.zeroForSaleToken
            ? tokenPairs[Keys.computePairKey(params.saleToken, params.holdToken)][1]
            : tokenPairs[Keys.computePairKey(params.holdToken, params.saleToken)][0];
        // Update the token rate information and retrieve the dailyRate and accLoanRatePerShare
        (cache.dailyRate, cache.accLoanRatePerShare) = _updateTokenRateInfo(holdTokenRateInfo);
        // Extract liquidity
        cache.borrowedAmount = _extractLiquidity(
            cache.zeroForSaleToken,
            params.saleToken,
            params.holdToken,
            params.loans
        );

        (cache.saleTokenBalance, cache.holdTokenBalance) = _getPairBalance(
            params.saleToken,
            params.holdToken
        );
        //console.log("saleTokenBalance before the swap =", saleTokenBalance);

        // If there are saleToken balances available, perform a swap to get more holdToken
        if (cache.saleTokenBalance > 0) {
            if (params.externalSwap.swapTarget != address(0)) {
                _approveIfNecessary(
                    params.saleToken,
                    params.externalSwap.swapTarget,
                    cache.saleTokenBalance
                );
                params.externalSwap.swapTarget._patchAmountAndCall(
                    params.externalSwap.maxGasForCall,
                    params.externalSwap.swapData,
                    params.externalSwap.swapAmountInDataIndex,
                    cache.saleTokenBalance,
                    params.externalSwap.swapAmountOutMinimumDataIndex,
                    0
                );
                cache.holdTokenBalance = _getBalance(params.holdToken);
            } else {
                cache.holdTokenBalance += _v3SwapExactInput(
                    v3SwapExactInputParams({
                        fee: params.swapPoolfee,
                        tokenIn: params.saleToken,
                        tokenOut: params.holdToken,
                        amountIn: cache.saleTokenBalance,
                        amountOutMinimum: 0
                    })
                );
            }
        }

        // Ensure that the received holdToken balance meets the minimum required

        //console.log("holdToken borrower owe =", borrowedAmount);
        //console.log("holdToken borrower has after the swap =", holdTokenBalance);
        require(cache.holdTokenBalance >= params.minHoldTokenOut, "too little received");
        require(
            (cache.borrowedAmount - cache.holdTokenBalance) <= params.maxCollateral,
            "too much collateral"
        );

        bytes32 borrowingKey = Keys.computeBorrowingKey(
            msg.sender,
            params.saleToken,
            params.holdToken
        );
        BorrowingInfo storage borrowing = borrowings[borrowingKey];

        if (borrowing.borrowedAmount > 0) {
            uint256 currentPerDayFees = FullMath.mulDiv(
                borrowing.borrowedAmount,
                cache.accLoanRatePerShare - borrowing.accLoanRatePerShare,
                FixedPoint96.Q96
            ) / Constants.BP;
            // Check if the collateral meets the required amount of fees
            require(
                borrowing.dailyRateCollateral >= currentPerDayFees,
                "collateral increase required"
            );
            // Calculate the platformFees and deduct from the dailyRateCollateral
            uint256 platformFees = (currentPerDayFees * platformFeesBP) / Constants.BP;
            currentPerDayFees -= platformFees;
            platformsFeesInfo[params.holdToken] += platformFees;
            borrowing.dailyRateCollateral -= currentPerDayFees;
            borrowing.feesOwed += currentPerDayFees;
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
        require(borrowing.loans.length < Constants.MAX_NUM_LOANS_PER_POSOTION, "too many loans");

        borrowing.accLoanRatePerShare = cache.accLoanRatePerShare;
        uint256 liquidationBonus = specificTokenLiquidationBonus[params.holdToken];
        liquidationBonus =
            (cache.borrowedAmount *
                (liquidationBonus > 0 ? liquidationBonus : dafaultLiquidationBonusBP) *
                params.loans.length) /
            Constants.BP;
        cache.dailyRate = (cache.borrowedAmount * cache.dailyRate) / Constants.BP; //prepayment per day

        borrowing.borrowedAmount += cache.borrowedAmount;
        borrowing.liquidationBonus += liquidationBonus;
        borrowing.dailyRateCollateral += cache.dailyRate;

        uint256 collateral = cache.borrowedAmount - cache.holdTokenBalance;
        holdTokenRateInfo.totalBorrowed += cache.borrowedAmount;
        // Transfer the required tokens to the VAULT_ADDRESS for collateral and holdTokenBalance
        _pay(
            params.holdToken,
            msg.sender,
            VAULT_ADDRESS,
            collateral + liquidationBonus + cache.dailyRate
        );
        console.log("leverage =", cache.holdTokenBalance / collateral);
        console.log(
            "leverage (with liquidationBonus + dailyRate)=",
            cache.holdTokenBalance / (collateral + liquidationBonus + cache.dailyRate)
        );
        _pay(params.holdToken, address(this), VAULT_ADDRESS, cache.holdTokenBalance);
        // Emit the Borrow event with the borrower, borrowing key, and borrowed amount
        emit Borrow(msg.sender, borrowingKey, cache.borrowedAmount);
    }

    /**
     * @notice Repays a borrowing
     * @param borrowingKey The key of the borrowing to be repaid
     * @param swapPoolFee The fee of swapping pool
     * @param slippageBP1000 The allowed slippage percentage for the swap, in basis points
     * @param deadline The deadline by which the transaction must be executed
     */
    function repay(
        bytes32 borrowingKey,
        uint24 swapPoolFee,
        uint256 slippageBP1000,
        uint256 deadline
    ) external nonReentrant checkDeadline(deadline) {
        BorrowingInfo memory borrowing = borrowings[borrowingKey];
        require(borrowing.borrowedAmount > 0, "invalid borrowingKey");
        bool zeroForSaleToken = borrowing.saleToken < borrowing.holdToken;
        uint256 feesOwed = borrowing.dailyRateCollateral;
        {
            // Calculate collateral balance and validate caller
            int256 collateralBalance;
            {
                TokenInfo storage holdTokenRateInfo = zeroForSaleToken
                    ? tokenPairs[Keys.computePairKey(borrowing.saleToken, borrowing.holdToken)][1]
                    : tokenPairs[Keys.computePairKey(borrowing.holdToken, borrowing.saleToken)][0];

                {
                    (, uint256 accLoanRatePerShare) = _updateTokenRateInfo(holdTokenRateInfo);

                    collateralBalance = _checkDailyRateCollateral(
                        borrowing.borrowedAmount,
                        borrowing.accLoanRatePerShare,
                        borrowing.dailyRateCollateral,
                        accLoanRatePerShare
                    );
                    require(
                        msg.sender == borrowing.borrower || collateralBalance < 0,
                        "invalid caller"
                    );
                }
            }
            // Calculate liquidation bonus and adjust fees owed
            {
                uint256 liquidationBonus = borrowing.liquidationBonus;
                if (collateralBalance > 0) {
                    feesOwed -= uint256(collateralBalance);
                    liquidationBonus += uint256(collateralBalance);
                }
                // Transfer liquidation bonus to msg.sender
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
        _approveIfNecessary(
            borrowing.holdToken,
            address(underlyingPositionManager),
            type(uint256).max - 1
        );
        _approveIfNecessary(
            borrowing.saleToken,
            address(underlyingPositionManager),
            type(uint256).max - 1
        );
        _restoreLiquidity(
            RestoreLiquidityParams({
                zeroForSaleToken: zeroForSaleToken,
                fee: swapPoolFee,
                slippageBP1000: slippageBP1000,
                totalfeesOwed: feesOwed,
                totalBorrowedAmount: borrowing.borrowedAmount
            }),
            loans
        );
        (uint256 saleTokenBalance, uint256 holdTokenBalance) = _getPairBalance(
            borrowing.saleToken,
            borrowing.holdToken
        );
        // Remove borrowing key from related data structures
        for (uint256 i; i < loans.length; ) {
            underlyingPosBorrowingKeys[loans[i].tokenId].removeKey(borrowingKey);
            unchecked {
                ++i;
            }
        }
        userBorrowingKeys[msg.sender].removeKey(borrowingKey);
        // Delete borrowing information
        delete borrowings[borrowingKey];
        // Pay a profit to a borrower
        _pay(borrowing.holdToken, address(this), msg.sender, holdTokenBalance);
        _pay(borrowing.saleToken, address(this), msg.sender, saleTokenBalance);

        emit Repay(borrowing.borrower, msg.sender, borrowingKey);
    }
}
