// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;
import "@uniswap/v3-core/contracts/libraries/FixedPoint96.sol";
import "../vendor0.8/uniswap/FullMath.sol";
import "../libraries/Keys.sol";
import { Constants } from "../libraries/Constants.sol";

// import "hardhat/console.sol";

abstract contract DailyRateAndCollateral {
    struct TokenInfo {
        uint32 latestUpTimestamp;
        uint256 accLoanRatePerSeconds;
        uint256 currentDailyRate;
        uint256 totalBorrowed;
    }

    /// pairKey => TokenInfo[]
    mapping(bytes32 => TokenInfo[2]) public tokenPairs;

    function _updateTokenRateInfo(
        address saleToken,
        address holdToken
    ) internal returns (uint256 currentDailyRate, TokenInfo storage holdTokenRateInfo) {
        holdTokenRateInfo = saleToken < holdToken
            ? tokenPairs[Keys.computePairKey(saleToken, holdToken)][1]
            : tokenPairs[Keys.computePairKey(holdToken, saleToken)][0];
        currentDailyRate = holdTokenRateInfo.currentDailyRate;
        if (currentDailyRate == 0) {
            currentDailyRate = Constants.DEFAULT_DAILY_RATE;
        }
        if (holdTokenRateInfo.totalBorrowed > 0) {
            uint256 timeWeightedRate = (uint32(block.timestamp) -
                holdTokenRateInfo.latestUpTimestamp) * currentDailyRate;
            holdTokenRateInfo.accLoanRatePerSeconds +=
                (timeWeightedRate * Constants.COLLATERAL_BALANCE_PRECISION) /
                1 days;
        }

        holdTokenRateInfo.latestUpTimestamp = uint32(block.timestamp);
    }

    function _getHoldTokenRateInfo(
        address saleToken,
        address holdToken
    ) internal view returns (uint256 currentDailyRate, uint256 accLoanRatePerSeconds) {
        TokenInfo memory holdTokenRateInfo = saleToken < holdToken
            ? tokenPairs[Keys.computePairKey(saleToken, holdToken)][1]
            : tokenPairs[Keys.computePairKey(holdToken, saleToken)][0];
        currentDailyRate = holdTokenRateInfo.currentDailyRate;
        if (currentDailyRate == 0) {
            currentDailyRate = Constants.DEFAULT_DAILY_RATE;
        }

        uint256 timeWeightedRate = (uint32(block.timestamp) - holdTokenRateInfo.latestUpTimestamp) *
            currentDailyRate;
        if (holdTokenRateInfo.totalBorrowed > 0) {
            // ?
            accLoanRatePerSeconds =
                holdTokenRateInfo.accLoanRatePerSeconds +
                (timeWeightedRate * Constants.COLLATERAL_BALANCE_PRECISION) /
                1 days;
        }
    }

    function _calculateCollateralBalance(
        uint256 borrowedAmount,
        uint256 borrowingAccLoanRatePerShare,
        uint256 borrowingDailyRateCollateral,
        uint256 accLoanRatePerSeconds
    ) internal pure returns (int256 collateralBalance, uint256 currentFees) {
        if (borrowedAmount > 0) {
            currentFees = FullMath.mulDivRoundingUp(
                borrowedAmount,
                accLoanRatePerSeconds - borrowingAccLoanRatePerShare,
                Constants.BP
            );
            collateralBalance = int256(borrowingDailyRateCollateral) - int256(currentFees);
        }
    }
}
