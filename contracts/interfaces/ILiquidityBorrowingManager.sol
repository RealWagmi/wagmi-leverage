// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;
import "./abstract/IApproveSwapAndPay.sol";
import "./abstract/ILiquidityManager.sol";
import "./abstract/IDailyRateAndCollateral.sol";
import "./abstract/IOwnerSettings.sol";

interface ILiquidityBorrowingManager is
    IApproveSwapAndPay,
    ILiquidityManager,
    IDailyRateAndCollateral,
    IOwnerSettings
{
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
        /// @notice The maximum amount of margin deposit that can be provided
        uint256 maxMarginDeposit;
        /// @notice The maximum allowable daily rate
        uint256 maxDailyRate;
        /// @notice The SwapParams struct representing the external swap parameters
        SwapParams[] externalSwap;
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
        /// @notice The amount of liquidation bonus
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
        uint256 holdTokenEntraceFee;
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
        /// @return returnOnlyHoldToken A boolean representing whether the contract returns only the HoldToken
        bool returnOnlyHoldToken;
        /// @notice The activation of the emergency liquidity restoration mode (available only to the lender)
        bool isEmergency;
        /// @notice The pool fee level for the internal swap
        uint24 internalSwapPoolfee;
        /// @notice The external swap parameters for the repayment transaction
        SwapParams[] externalSwap;
        /// @notice The unique borrowing key associated with the loan
        bytes32 borrowingKey;
        /// minimun expected hold token out
        uint256 minHoldTokenOut;
        /// minimun expected sale token out
        uint256 minSaleTokenOut;
    }

    /// Indicates that a borrower has made a new loan
    event Borrow(
        address borrower,
        bytes32 borrowingKey,
        uint256 borrowedAmount,
        uint256 borrowingCollateral,
        uint256 liquidationBonus,
        uint256 dailyRatePrepayment,
        uint256 feesDebt,
        uint256 holdTokenEntraceFee
    );
    /// Indicates that a borrower has repaid their loan, optionally with the help of a liquidator
    event Repay(address borrower, address liquidator, bytes32 borrowingKey);
    /// Indicates that a loan has been closed due to an emergency situation
    event EmergencyLoanClosure(address borrower, address lender, bytes32 borrowingKey);
    /// Indicates that the protocol has collected fee tokens
    event CollectProtocol(address recipient, address[] tokens, uint256[] amounts);
    /// Indicates that the lender has collected fee tokens
    event CollectLoansFees(address recipient, address[] tokens, uint256[] amounts);
    /// Indicates that the daily interest rate for holding token(for specific pair) has been updated
    event UpdateHoldTokenDailyRate(address saleToken, address holdToken, uint256 value);
    /// Indicates that the entrance fee for holding token(for specific pair) has been updated
    event UpdateHoldTokeEntranceFee(address saleToken, address holdToken, uint256 value);
    /// Indicates that a borrower has increased their collateral balance for a loan
    event IncreaseCollateralBalance(address borrower, bytes32 borrowingKey, uint256 collateralAmt);

    event Harvest(bytes32 borrowingKey, uint256 harvestedAmt);

    error TooLittleReceivedError(uint256 minOut, uint256 out);

    function getLoansInfo(bytes32 borrowingKey) external view returns (LoanInfo[] memory loans);

    function borrowingsInfo(
        bytes32 borrowingKey
    )
        external
        view
        returns (
            address borrower,
            address saleToken,
            address holdToken,
            uint256 feesOwed,
            uint256 borrowedAmount,
            uint256 liquidationBonus,
            uint256 accLoanRatePerSeconds,
            uint256 dailyRateCollateralBalance
        );

    function collectProtocol(address recipient, address[] calldata tokens) external;

    function collectLoansFees(address[] calldata tokens) external;

    function setSwapCallToWhitelist(
        address swapTarget,
        bytes4 funcSelector,
        bool isAllowed
    ) external;

    function updateHoldTokenDailyRate(address saleToken, address holdToken, uint256 value) external;

    function updateHoldTokenEntranceFee(
        address saleToken,
        address holdToken,
        uint256 value
    ) external;

    function checkDailyRateCollateral(
        bytes32 borrowingKey
    ) external view returns (int256 balance, uint256 estimatedLifeTime);

    function getLenderCreditsInfo(
        uint256 tokenId
    ) external view returns (BorrowingInfoExt[] memory extinfo);

    function getBorrowingKeysForTokenId(
        uint256 tokenId
    ) external view returns (bytes32[] memory borrowingKeys);

    function getBorrowingKeysForBorrower(
        address borrower
    ) external view returns (bytes32[] memory borrowingKeys);

    function getBorrowerDebtsInfo(
        address borrower
    ) external view returns (BorrowingInfoExt[] memory extinfo);

    function getLenderCreditsCount(uint256 tokenId) external view returns (uint256 count);

    function getBorrowerDebtsCount(address borrower) external view returns (uint256 count);

    function getLiquidationBonus(
        address token,
        uint256 borrowedAmount,
        uint256 times
    ) external view returns (uint256 liquidationBonus);

    function getHoldTokenInfo(
        address saleToken,
        address holdToken
    ) external view returns (TokenInfo memory holdTokenRateInfo);

    function getFeesInfo(
        address feesOwner,
        address[] calldata tokens
    ) external view returns (uint256[] memory fees);

    function getPlatformFeesInfo(
        address[] calldata tokens
    ) external view returns (uint256[] memory fees);

    function calculateCollateralAmtForLifetime(
        bytes32 borrowingKey,
        uint256 lifetimeInSeconds
    ) external view returns (uint256 collateralAmt);

    function increaseCollateralBalance(
        bytes32 borrowingKey,
        uint256 collateralAmt,
        uint256 deadline
    ) external;

    function harvest(bytes32 borrowingKey) external returns (uint256 harvestedAmt);

    function borrow(
        BorrowParams calldata params,
        uint256 deadline
    )
        external
        returns (
            uint256 borrowedAmount,
            uint256 marginDeposit,
            uint256 liquidationBonus,
            uint256 dailyRateCollateral,
            uint256 holdTokenEntraceFee
        );

    function repay(
        RepayParams calldata params,
        uint256 deadline
    ) external returns (uint256 saleTokenOut, uint256 holdTokenOut);
}
