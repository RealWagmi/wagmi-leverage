// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

/// @title Constant state
library Constants {
    uint256 public constant BP = 10000;
    uint256 public constant BPS = 1000;
    uint256 public constant DEFAULT_DAILY_RATE = 10; // 0.1%
    uint256 public constant MAX_PLATFORM_FEE = 2000; // 20%
    uint256 public constant MAX_LIQUIDATION_BONUS = 100; // 1%
}
