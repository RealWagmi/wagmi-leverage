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

    event return$_extractLiquidity(uint256 borrowedAmount);

    event return$_v3SwapExactInput(uint256 amountOut);

    constructor(
        address _underlyingPositionManagerAddress,
        address _lightQuoterV3,
        address _underlyingV3Factory,
        bytes32 _underlyingV3PoolInitCodeHash
    )
        payable
        LiquidityManager(
            _underlyingPositionManagerAddress,
            _lightQuoterV3,
            _underlyingV3Factory,
            _underlyingV3PoolInitCodeHash
        )
    {}

    function $loansFeesInfo(address arg0, address arg1) external view returns (uint256) {
        return loansFeesInfo[arg0][arg1];
    }

    function $MIN_SQRT_RATIO() external pure returns (uint160) {
        return MIN_SQRT_RATIO;
    }

    function $MAX_SQRT_RATIO() external pure returns (uint160) {
        return MAX_SQRT_RATIO;
    }

    function $_getMinLiquidityAmt(
        int24 tickLower,
        int24 tickUpper
    ) external pure returns (uint128 minLiquidity) {
        (minLiquidity) = super._getMinLiquidityAmt(tickLower, tickUpper);
    }

    function $_extractLiquidity(
        bool zeroForSaleToken,
        address saleToken,
        address holdToken,
        LoanInfo[] calldata loans
    ) external returns (uint256 borrowedAmount) {
        (borrowedAmount) = super._extractLiquidity(zeroForSaleToken, saleToken, holdToken, loans);
        emit return$_extractLiquidity(borrowedAmount);
    }

    function $_simulateSwap(
        bool zeroForIn,
        uint24 fee,
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external view returns (uint160 sqrtPriceX96After, uint256 amountOut) {
        (sqrtPriceX96After, amountOut) = super._simulateSwap(
            zeroForIn,
            fee,
            tokenIn,
            tokenOut,
            amountIn
        );
    }

    function $_restoreLiquidity(
        RestoreLiquidityParams calldata params,
        LoanInfo[] calldata loans
    ) external {
        super._restoreLiquidity(params, loans);
    }

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

    function $_maxApproveIfNecessary(address token, address spender, uint256 amount) external {
        super._maxApproveIfNecessary(token, spender, amount);
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

    function $_v3SwapExactInput(
        v3SwapExactInputParams calldata params
    ) external returns (uint256 amountOut) {
        (amountOut) = super._v3SwapExactInput(params);
        emit return$_v3SwapExactInput(amountOut);
    }

    receive() external payable {}
}
