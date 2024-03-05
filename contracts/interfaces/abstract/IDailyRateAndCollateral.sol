// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

interface IDailyRateAndCollateral {
    /**
     * @dev Struct representing information about a token.
     * @param latestUpTimestamp The timestamp of the latest update for the token information.
     * @param accLoanRatePerSeconds The accumulated loan rate per second for the token.
     * @param currentDailyRate The current daily loan rate for the token.
     * @param totalBorrowed The total amount borrowed for the token.
     * @param entranceFeeBP The entrance fee in basis points for the token.
     */
    struct TokenInfo {
        uint32 latestUpTimestamp;
        uint256 accLoanRatePerSeconds;
        uint256 currentDailyRate;
        uint256 totalBorrowed;
        uint256 entranceFeeBP;
    }
}
