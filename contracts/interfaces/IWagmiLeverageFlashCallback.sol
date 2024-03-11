// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

interface IWagmiLeverageFlashCallback {
    function wagmiLeverageFlashCallback(
        uint256 bodyAmt,
        uint256 feeAmt,
        bytes calldata data
    ) external;
}
