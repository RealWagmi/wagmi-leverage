// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IFlashLoanAggregator {
    function flashLoan(uint256 amount, bytes calldata data) external;
}
