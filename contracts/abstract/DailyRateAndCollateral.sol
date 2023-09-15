// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;
import "@uniswap/v3-core/contracts/libraries/FixedPoint96.sol";
import "../vendor0.8/uniswap/FullMath.sol";
import "../libraries/Keys.sol";
import { Constants } from "../libraries/Constants.sol";

abstract contract DailyRateAndCollateral {
    struct TokenInfo {
        uint32 latestUpTimestamp;
        uint256 accLoanRatePerShare;
        uint256 currentDailyRate;
        uint256 totalBorrowed;
    }

    /// pairKey => TokenInfo[]
    mapping(bytes32 => TokenInfo[2]) public tokenPairs;

    function _updateTokenRateInfo(
        TokenInfo storage holdTokenRateInfo
    ) internal returns (uint256 currentDailyRate, uint256 accLoanRatePerShare) {
        currentDailyRate = holdTokenRateInfo.currentDailyRate;
        if (currentDailyRate == 0) {
            currentDailyRate = Constants.DEFAULT_DAILY_RATE;
        }
        if (holdTokenRateInfo.totalBorrowed > 0) {
            uint256 timeWeightedRate = (uint32(block.timestamp) -
                holdTokenRateInfo.latestUpTimestamp) * currentDailyRate;
            holdTokenRateInfo.accLoanRatePerShare +=
                (timeWeightedRate * FixedPoint96.Q96) /
                holdTokenRateInfo.totalBorrowed;
        }
        holdTokenRateInfo.latestUpTimestamp = uint32(block.timestamp);
        accLoanRatePerShare = holdTokenRateInfo.accLoanRatePerShare;
    }

    function _getHoldTokenRateInfo(
        address saleToken,
        address holdToken
    ) internal view returns (uint256 currentDailyRate, uint256 accLoanRatePerShare) {
        TokenInfo memory holdTokenRateInfo = saleToken < holdToken
            ? tokenPairs[Keys.computePairKey(saleToken, holdToken)][1]
            : tokenPairs[Keys.computePairKey(holdToken, saleToken)][0];
        currentDailyRate = holdTokenRateInfo.currentDailyRate;
        if (currentDailyRate == 0) {
            currentDailyRate = Constants.DEFAULT_DAILY_RATE;
        }
        uint256 timeWeightedRate = (uint32(block.timestamp) - holdTokenRateInfo.latestUpTimestamp) *
            currentDailyRate;
        accLoanRatePerShare =
            holdTokenRateInfo.accLoanRatePerShare +
            (timeWeightedRate * FixedPoint96.Q96) /
            holdTokenRateInfo.totalBorrowed;
    }

    function _checkDailyRateCollateral(
        uint256 borrowedAmount,
        uint256 borrowingAccLoanRatePerShare,
        uint256 borrowingDailyRateCollateral,
        uint256 accLoanRatePerShare
    ) internal pure returns (int256 balance) {
        if (borrowedAmount > 0) {
            uint256 currentPerDayFees = FullMath.mulDiv(
                borrowedAmount,
                accLoanRatePerShare - borrowingAccLoanRatePerShare,
                FixedPoint96.Q96
            ) / Constants.BP;
            balance = int256(borrowingDailyRateCollateral) - int256(currentPerDayFees);
        }
    }
}
