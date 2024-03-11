// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.6.0;

import "../../../../contracts/abstract/ApproveSwapAndPay.sol";
import "../../../../contracts/libraries/TransferHelper.sol";
import "../../../../contracts/interfaces/IUniswapV3Pool.sol";
import "../../../../contracts/interfaces/abstract/IApproveSwapAndPay.sol";
import "../../../../contracts/vendor0.8/uniswap/SafeCast.sol";
import "../../../../contracts/libraries/Keys.sol";
import "../../../../contracts/libraries/ExternalCall.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract $ApproveSwapAndPay is ApproveSwapAndPay {
    using EnumerableSet for EnumerableSet.Bytes32Set;
    bytes32 public constant __hh_exposed_bytecode_marker = "hardhat-exposed";
    EnumerableSet.Bytes32Set self;

    event return$_v3SwapExact(uint256 amountOut);

    constructor(
        address _UNDERLYING_V3_FACTORY_ADDRESS,
        bytes32 _UNDERLYING_V3_POOL_INIT_CODE_HASH
    )
        payable
        ApproveSwapAndPay(_UNDERLYING_V3_FACTORY_ADDRESS, _UNDERLYING_V3_POOL_INIT_CODE_HASH)
    {}

    function $_maxApproveIfNecessary(address token, address spender) external {
        super._maxApproveIfNecessary(token, spender);
    }

    function $_getBalance(address token) external view returns (uint256 balance) {
        (balance) = super._getBalance(token);
    }

    function $_removeKey(bytes32 key) external {
        self.remove(key);
    }

    function $_addKeyIfNotExists(bytes32 key) external {
        self.add(key);
    }

    function $getSelf() external view returns (bytes32[] memory) {
        return self.values();
    }

    function $_computePairKey(
        address saleToken,
        address holdToken
    ) external pure returns (bytes32) {
        return Keys.computePairKey(saleToken, holdToken);
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

    function $_setSwapCallToWhitelist(
        address swapTarget,
        bytes4 funcSelector,
        bool isAllowed
    ) external {
        whitelistedCall[swapTarget][funcSelector] = isAllowed;
    }

    receive() external payable {}
}
