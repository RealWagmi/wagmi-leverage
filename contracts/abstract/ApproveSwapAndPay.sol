// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.21;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IUniswapV3Pool } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import { SafeCast } from "@uniswap/v3-core/contracts/libraries/SafeCast.sol";
import "../libraries/ExternalCall.sol";
import "../libraries/ErrLib.sol";

abstract contract ApproveSwapAndPay {
    using SafeCast for uint256;
    using SafeERC20 for IERC20;
    using { ExternalCall._patchAmountAndCall } for address;
    using { ExternalCall._readFirstBytes4 } for bytes;
    using { ErrLib.revertError } for bool;

    struct v3SwapExactInputParams {
        uint24 fee;
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 amountOutMinimum;
    }

    /// @notice Struct to hold parameters for swapping tokens
    struct SwapParams {
        /// @notice Address of the aggregator's router
        address swapTarget;
        /// @notice The index in the `swapData` array where the swap amount in is stored
        uint256 swapAmountInDataIndex;
        /// @notice The maximum gas limit for the swap call
        uint256 maxGasForCall;
        /// @notice The aggregator's data that stores paths and amounts for swapping through
        bytes swapData;
    }

    /// @dev The minimum value that can be returned from #getSqrtRatioAtTick. Equivalent to getSqrtRatioAtTick(MIN_TICK)
    uint160 internal constant MIN_SQRT_RATIO = 4295128739;

    /// @dev The maximum value that can be returned from #getSqrtRatioAtTick. Equivalent to getSqrtRatioAtTick(MAX_TICK)
    uint160 internal constant MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970342;

    address public immutable UNDERLYING_V3_FACTORY_ADDRESS;
    bytes32 public immutable UNDERLYING_V3_POOL_INIT_CODE_HASH;

    ///     swapTarget   => (func.selector => is allowed)
    mapping(address => mapping(bytes4 => bool)) public whitelistedCall;

    error SwapSlippageCheckError(uint256 expectedOut, uint256 receivedOut);

    constructor(
        address _UNDERLYING_V3_FACTORY_ADDRESS,
        bytes32 _UNDERLYING_V3_POOL_INIT_CODE_HASH
    ) {
        UNDERLYING_V3_FACTORY_ADDRESS = _UNDERLYING_V3_FACTORY_ADDRESS;
        UNDERLYING_V3_POOL_INIT_CODE_HASH = _UNDERLYING_V3_POOL_INIT_CODE_HASH;
    }

    function _tryApprove(address token, address spender, uint256 amount) private returns (bool) {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.approve.selector, spender, amount)
        );
        return success && (data.length == 0 || abi.decode(data, (bool)));
    }

    function _maxApproveIfNecessary(address token, address spender, uint256 amount) internal {
        if (IERC20(token).allowance(address(this), spender) < amount) {
            if (!_tryApprove(token, spender, type(uint256).max)) {
                if (!_tryApprove(token, spender, type(uint256).max - 1)) {
                    require(_tryApprove(token, spender, 0));
                    if (!_tryApprove(token, spender, type(uint256).max)) {
                        if (!_tryApprove(token, spender, type(uint256).max - 1)) {
                            true.revertError(ErrLib.ErrorCode.ERC20_APPROVE_DID_NOT_SUCCEED);
                        }
                    }
                }
            }
        }
    }

    function _getBalance(address token) internal view returns (uint256 balance) {
        bytes memory callData = abi.encodeWithSelector(IERC20.balanceOf.selector, address(this));
        (bool success, bytes memory data) = token.staticcall(callData);
        require(success && data.length >= 32);
        balance = abi.decode(data, (uint256));
    }

    function _getPairBalance(
        address tokenA,
        address tokenB
    ) internal view returns (uint256 balanceA, uint256 balanceB) {
        balanceA = _getBalance(tokenA);
        balanceB = _getBalance(tokenB);
    }

    function _patchAmountsAndCallSwap(
        address tokenIn,
        address tokenOut,
        SwapParams calldata externalSwap,
        uint256 amountIn,
        uint256 amountOutMin
    ) internal returns (uint256 amountOut) {
        bytes4 funcSelector = externalSwap.swapData._readFirstBytes4();
        (!whitelistedCall[externalSwap.swapTarget][funcSelector]).revertError(
            ErrLib.ErrorCode.SWAP_TARGET_NOT_APPROVED
        );

        _maxApproveIfNecessary(tokenIn, externalSwap.swapTarget, amountIn);
        uint256 balanceOutBefore = _getBalance(tokenOut);

        externalSwap.swapTarget._patchAmountAndCall(
            externalSwap.swapData,
            externalSwap.maxGasForCall,
            externalSwap.swapAmountInDataIndex,
            amountIn
        );
        amountOut = _getBalance(tokenOut) - balanceOutBefore;
        if (amountOut == 0 || amountOut < amountOutMin) {
            revert SwapSlippageCheckError(amountOutMin, amountOut);
        }
    }

    function _pay(address token, address payer, address recipient, uint256 value) internal {
        if (value > 0) {
            if (payer == address(this)) {
                IERC20(token).safeTransfer(recipient, value);
            } else {
                IERC20(token).safeTransferFrom(payer, recipient, value);
            }
        }
    }

    function _v3SwapExactInput(
        v3SwapExactInputParams memory params
    ) internal returns (uint256 amountOut) {
        bool zeroForTokenIn = params.tokenIn < params.tokenOut;
        (int256 amount0Delta, int256 amount1Delta) = IUniswapV3Pool(
            computePoolAddress(params.tokenIn, params.tokenOut, params.fee)
        ).swap(
                address(this), //recipient
                zeroForTokenIn,
                params.amountIn.toInt256(),
                (zeroForTokenIn ? MIN_SQRT_RATIO + 1 : MAX_SQRT_RATIO - 1),
                abi.encode(params.fee, params.tokenIn, params.tokenOut)
            );
        amountOut = uint256(-(zeroForTokenIn ? amount1Delta : amount0Delta));
        if (amountOut < params.amountOutMinimum) {
            revert SwapSlippageCheckError(params.amountOutMinimum, amountOut);
        }
    }

    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external {
        (amount0Delta <= 0 && amount1Delta <= 0).revertError(ErrLib.ErrorCode.INVALID_SWAP); // swaps entirely within 0-liquidity regions are not supported

        (uint24 fee, address tokenIn, address tokenOut) = abi.decode(
            data,
            (uint24, address, address)
        );
        (computePoolAddress(tokenIn, tokenOut, fee) != msg.sender).revertError(
            ErrLib.ErrorCode.INVALID_CALLER
        );
        uint256 amountToPay = amount0Delta > 0 ? uint256(amount0Delta) : uint256(amount1Delta);
        _pay(tokenIn, address(this), msg.sender, amountToPay);
    }

    function computePoolAddress(
        address tokenA,
        address tokenB,
        uint24 fee
    ) public view returns (address pool) {
        if (tokenA > tokenB) (tokenA, tokenB) = (tokenB, tokenA);
        pool = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex"ff",
                            UNDERLYING_V3_FACTORY_ADDRESS,
                            keccak256(abi.encode(tokenA, tokenB, fee)),
                            UNDERLYING_V3_POOL_INIT_CODE_HASH
                        )
                    )
                )
            )
        );
    }
}
