// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.6.0;

import "../../../../contracts/abstract/LiquidityManager.sol";
import "../../../../contracts/libraries/Constants.sol";
import "../../../../contracts/libraries/ErrLib.sol";
import "../../../../contracts/libraries/AmountsLiquidity.sol";
import "../../../../contracts/interfaces/abstract/ILiquidityManager.sol";
import "../../../../contracts/abstract/ApproveSwapAndPay.sol";
import "../../../../contracts/interfaces/abstract/IApproveSwapAndPay.sol";

contract $LiquidityManager is LiquidityManager {
    bytes32 public constant __hh_exposed_bytecode_marker = "hardhat-exposed";

    event return$_v3SwapExact(uint256 amountOut);

    constructor(
        address _underlyingPositionManagerAddress,
        address _flashLoanAggregator,
        address _lightQuoterV3,
        address _underlyingV3Factory,
        bytes32 _underlyingV3PoolInitCodeHash
    )
        payable
        LiquidityManager(
            _underlyingPositionManagerAddress,
            _flashLoanAggregator,
            _lightQuoterV3,
            _underlyingV3Factory,
            _underlyingV3PoolInitCodeHash
        )
    {}

    function $loansFeesInfo(address arg0, address arg1) external view returns (uint256) {
        return loansFeesInfo[arg0][arg1];
    }

    function $_getMinLiquidityAmt(
        int24 tickLower,
        int24 tickUpper
    ) external pure returns (uint128 minLiquidity) {
        (minLiquidity) = super._getMinLiquidityAmt(tickLower, tickUpper);
    }

    // function $_simulateSwap(
    //     bool exactIn,
    //     bool zeroForIn,
    //     uint24 fee,
    //     address tokenIn,
    //     address tokenOut,
    //     uint256 amountIn
    // ) external view returns (uint160 sqrtPriceX96After, uint256 amountOut) {
    //     (sqrtPriceX96After, amountOut) = super._simulateSwap(
    //         exactIn,
    //         zeroForIn,
    //         fee,
    //         tokenIn,
    //         tokenOut,
    //         amountIn
    //     );
    // }

    function $_getOwnerOf(uint256 tokenId) external view returns (address tokenOwner) {
        (tokenOwner) = super._getOwnerOf(tokenId);
    }

    function $_upNftPositionCache(
        bool zeroForSaleToken,
        LoanInfo calldata loan,
        NftPositionCache calldata cache
    ) external view {
        super._upNftPositionCache(zeroForSaleToken, loan, cache);
    }

    function $_maxApproveIfNecessary(address token, address spender) external {
        super._maxApproveIfNecessary(token, spender);
    }

    function $_getBalance(address token) external view returns (uint256 balance) {
        (balance) = super._getBalance(token);
    }

    function $_getPairBalance(
        address tokenA,
        address tokenB
    ) external view returns (uint256 balanceA, uint256 balanceB) {
        (balanceA, balanceB) = super._getPairBalance(tokenA, tokenB);
    }

    function $_callExternalSwap(address tokenIn, SwapParams[] calldata externalSwap) external {
        super._callExternalSwap(tokenIn, externalSwap);
    }

    function $_pay(address token, address payer, address recipient, uint256 value) external {
        super._pay(token, payer, recipient, value);
    }

    function $_v3SwapExact(v3SwapExactParams calldata params) external returns (uint256 amountOut) {
        (amountOut) = super._v3SwapExact(params);
        emit return$_v3SwapExact(amountOut);
    }

    receive() external payable {}
}
