// SPDX-License-Identifier: SAL-1.0
pragma solidity 0.8.23;
import "../vendor0.8/uniswap/FullMath.sol";
import "../libraries/Keys.sol";
import { Constants } from "../libraries/Constants.sol";
import "../interfaces/abstract/IDailyRateAndCollateral.sol";

abstract contract DailyRateAndCollateral is IDailyRateAndCollateral {
    /// pairKey => TokenInfo
    mapping(bytes32 => TokenInfo) internal holdTokenInfo;

    /**
     * @notice Adjusts the entrance fee basis points according to predefined rules.
     * @dev This function normalizes the entrance fee basis points (BP). If the entrance fee is zero, it defaults to
     *      `Constants.DEFAULT_ENTRANCE_FEE_BPS`. To disable entrance fees completely, the entrance fee BP should be set
     *      to `Constants.MAX_ENTRANCE_FEE_BPS + 1`, which will reset the fee to zero. This function should only be used internally.
     * @param entranceFeeBP The initial entrance fee in basis points proposed for a financial operation.
     * @return The normalized entrance fee in basis points after applying the adjustment rules.
     */
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
     * @notice Updates the hold token rate information for a given pair of sale and hold tokens
     * @dev This internal function updates the `accLoanRatePerSeconds` and `latestUpTimestamp` in the `holdTokenInfo` mapping.
     *      It also returns the latest `currentDailyRate` and the updated `holdTokenRateInfo` storage reference.
     * @param saleToken The address of the sale token in the pair
     * @param holdToken The address of the hold token in the pair
     * @return currentDailyRate The current daily rate for the hold token after the update
     * @return holdTokenRateInfo A storage reference to the hold token's rate info in the `holdTokenInfo` mapping
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
     * @notice Calculates the collateral balance and current fees for a borrowing operation.
     * @dev If there is a borrowed amount, this function computes the accrued fees since the time of borrowing. It uses full precision math
     *      for fee calculations, rounding up the result. The collateral balance is then updated by subtracting the fees from the initial
     *      daily rate collateral value.
     * @param borrowedAmount The principal amount that was borrowed.
     * @param borrowingAccLoanRatePerShare The accumulated loan rate per share at the time when the amount was borrowed.
     * @param borrowingDailyRateCollateral The total collateral balance associated with the daily rate at the time of borrowing.
     * @param accLoanRatePerSeconds The latest available accumulated loan rate per second.
     * @return collateralBalance The updated collateral balance after accounting for the accrued fees.
     * @return currentFees The total fees accrued since the time of borrowing.
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

    /**
     * @notice Retrieves the hash key and TokenInfo information for a holder token associated with a sale token.
     * @dev This function computes the unique pair key using `Keys.computePairKey` for the provided `saleToken`
     *      and `holdToken` and fetches the corresponding `TokenInfo`. If the current daily rate for the hold token
     *      is zero, it defaults to `Constants.DEFAULT_DAILY_RATE`. It then calculates and updates the time weighted rate
     *      if there has been any borrowing against the hold token. Lastly, it updates the `latestUpTimestamp` to the current
     *      block timestamp.
     * @param saleToken The address of the sale token that is being used in association with a hold token.
     * @param holdToken The address of the hold token whose information is being retrieved.
     * @return key A bytes32 type representing the unique pair key for the sale token and hold token.
     * @return holdTokenRateInfo A `TokenInfo` struct containing rate information for the hold token.
     */
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
