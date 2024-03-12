// SPDX-License-Identifier: SAL-1.0
pragma solidity 0.8.23;
import "../vendor0.8/uniswap/FullMath.sol";
import "../libraries/Keys.sol";
import { Constants } from "../libraries/Constants.sol";
import "../interfaces/abstract/IDailyRateAndCollateral.sol";

abstract contract DailyRateAndCollateral is IDailyRateAndCollateral {
    /// pairKey => TokenInfo
    mapping(bytes32 => TokenInfo) internal holdTokenInfo;

    function _checkEntranceFee(uint256 entranceFeeBP) internal pure returns (uint256) {
        if (entranceFeeBP == 0) {
            entranceFeeBP = Constants.DEFAULT_ENTRANCE_FEE_BPS;
        } else if (entranceFeeBP == Constants.MAX_ENTRANCE_FEE_BPS + 1) {
            // To disable entry fees, set it to MAX_ENTRANCE_FEE_BPS + 1
            entranceFeeBP = 0;
        }
        return entranceFeeBP;
    }

    /**
     * @notice This internal view function retrieves the current daily rate for the hold token specified by `holdToken`
     * in relation to the sale token specified by `saleToken`. It also returns detailed information about the hold token rate stored
     * in the `holdTokenInfo` mapping. If the rate is not set, it defaults to `Constants.DEFAULT_DAILY_RATE`. If there are any existing
     * borrowings for the hold token, the accumulated loan rate per second is updated based on the time difference since the last update and the
     * current daily rate. The latest update timestamp is also recorded for future calculations.
     * @param saleToken The address of the sale token in the pair.
     * @param holdToken The address of the hold token in the pair.
     * @return holdTokenRateInfo The struct containing information about the hold token rate.
     */
    function _getHoldTokenInfo(
        address saleToken,
        address holdToken
    ) internal view returns (TokenInfo memory) {
        (, TokenInfo memory holdTokenRateInfo) = _getHTInfo(saleToken, holdToken);
        holdTokenRateInfo.entranceFeeBP = _checkEntranceFee(holdTokenRateInfo.entranceFeeBP);
        return holdTokenRateInfo;
    }

    /**
     * @notice This internal function updates the hold token rate information for the pair of sale token specified by `saleToken`
     * and hold token specified by `holdToken`. It retrieves the existing hold token rate information from the `holdTokenInfo` mapping,
     * including the current daily rate. If the current daily rate is not set, it defaults to `Constants.DEFAULT_DAILY_RATE`.
     * If there are any existing borrowings for the hold token, the accumulated loan rate per second is updated based on the time
     * difference since the last update and the current daily rate. Finally, the latest update timestamp is recorded for future calculations.
     * @param saleToken The address of the sale token in the pair.
     * @param holdToken The address of the hold token in the pair.
     * @return currentDailyRate The updated current daily rate for the hold token.
     * @return holdTokenRateInfo The struct containing the updated hold token rate information.
     */
    function _updateHoldTokenRateInfo(
        address saleToken,
        address holdToken
    ) internal returns (uint256, TokenInfo storage) {
        (bytes32 key, TokenInfo memory info) = _getHTInfo(saleToken, holdToken);
        TokenInfo storage holdTokenRateInfo = holdTokenInfo[key];
        holdTokenRateInfo.accLoanRatePerSeconds = info.accLoanRatePerSeconds;
        holdTokenRateInfo.latestUpTimestamp = info.latestUpTimestamp;
        return (info.currentDailyRate, holdTokenRateInfo);
    }

    /**
     * @notice This internal function calculates the collateral balance and current fees.
     * If the `borrowedAmount` is greater than 0, it calculates the fees based on the difference between the current accumulated
     * loan rate per second (`accLoanRatePerSeconds`) and the accumulated loan rate per share at the time of borrowing (`borrowingAccLoanRatePerShare`).
     * The fees are calculated using the FullMath library's `mulDivRoundingUp()` function, rounding up the result to the nearest integer.
     * The collateral balance is then calculated by subtracting the fees from the daily rate collateral at the time of borrowing (`borrowingDailyRateCollateral`).
     * Both the collateral balance and fees are returned as the function's output.
     * @param borrowedAmount The amount borrowed.
     * @param borrowingAccLoanRatePerShare The accumulated loan rate per share at the time of borrowing.
     * @param borrowingDailyRateCollateral The daily rate collateral at the time of borrowing.
     * @param accLoanRatePerSeconds The current accumulated loan rate per second.
     * @return collateralBalance The calculated collateral balance after deducting fees.
     * @return currentFees The calculated fees for the borrowing operation.
     */
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

    function _getHTInfo(
        address saleToken,
        address holdToken
    ) private view returns (bytes32 key, TokenInfo memory holdTokenRateInfo) {
        key = Keys.computePairKey(saleToken, holdToken);
        holdTokenRateInfo = holdTokenInfo[key];

        if (holdTokenRateInfo.currentDailyRate == 0) {
            holdTokenRateInfo.currentDailyRate = Constants.DEFAULT_DAILY_RATE;
        }
        if (holdTokenRateInfo.totalBorrowed > 0) {
            unchecked {
                uint256 timeWeightedRate = (uint32(block.timestamp) -
                    holdTokenRateInfo.latestUpTimestamp) * holdTokenRateInfo.currentDailyRate;
                holdTokenRateInfo.accLoanRatePerSeconds +=
                    (timeWeightedRate * Constants.COLLATERAL_BALANCE_PRECISION) /
                    1 days;
            }
        }

        holdTokenRateInfo.latestUpTimestamp = uint32(block.timestamp);
    }
}
