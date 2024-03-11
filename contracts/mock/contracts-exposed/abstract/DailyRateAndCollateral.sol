// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.6.0;

import "../../../../contracts/abstract/DailyRateAndCollateral.sol";
import "../../../../contracts/libraries/Constants.sol";
import "../../../../contracts/interfaces/abstract/IDailyRateAndCollateral.sol";

contract $DailyRateAndCollateral is DailyRateAndCollateral {
    bytes32 public constant __hh_exposed_bytecode_marker = "hardhat-exposed";

    event return$_updateHoldTokenRateInfo(uint256 ret0, TokenInfo ret1);

    constructor() payable {}

    function $_checkEntranceFee(uint128 entranceFeeBP) external pure returns (uint256 ret0) {
        (ret0) = super._checkEntranceFee(entranceFeeBP);
    }

    function $_getHoldTokenInfo(
        address saleToken,
        address holdToken
    ) external view returns (TokenInfo memory ret0) {
        (ret0) = super._getHoldTokenInfo(saleToken, holdToken);
    }

    function $_updateHoldTokenRateInfo(
        address saleToken,
        address holdToken
    ) external returns (uint256 ret0, TokenInfo memory ret1) {
        (ret0, ret1) = super._updateHoldTokenRateInfo(saleToken, holdToken);
        emit return$_updateHoldTokenRateInfo(ret0, ret1);
    }

    function $_calculateCollateralBalance(
        uint128 borrowedAmount,
        uint256 borrowingAccLoanRatePerShare,
        uint256 borrowingDailyRateCollateral,
        uint256 accLoanRatePerSeconds
    ) external pure returns (int256 collateralBalance, uint256 currentFees) {
        (collateralBalance, currentFees) = super._calculateCollateralBalance(
            borrowedAmount,
            borrowingAccLoanRatePerShare,
            borrowingDailyRateCollateral,
            accLoanRatePerSeconds
        );
    }

    receive() external payable {}
}
