// SPDX-License-Identifier: SAL-1.0
pragma solidity 0.8.21;

/// @title Constant state
library Constants {
    uint256 internal constant BP = 10000;
    uint256 internal constant BPS = 1000;
    uint256 internal constant DEFAULT_DAILY_RATE = 10; // 0.1%
    uint256 internal constant MAX_PLATFORM_FEE = 2000; // 20%
    uint256 internal constant MAX_LIQUIDATION_BONUS = 100; // 1%
    uint256 internal constant MAX_DAILY_RATE = 10000; // 100%
    uint256 internal constant MIN_DAILY_RATE = 5; // 0.05 %
    uint256 internal constant MAX_ENTRANCE_FEE_BPS = 1000; // 10%
    uint256 internal constant DEFAULT_ENTRANCE_FEE_BPS = 10; // 0.1%
    uint256 internal constant MAX_NUM_LOANS_PER_POSITION = 7;
    uint256 internal constant COLLATERAL_BALANCE_PRECISION = 1e18;
    uint256 internal constant MINIMUM_AMOUNT = 1000;
    uint256 internal constant MINIMUM_EXTRACTED_AMOUNT = 10;
}
