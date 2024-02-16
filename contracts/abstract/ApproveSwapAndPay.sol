// SPDX-License-Identifier: SAL-1.0
pragma solidity 0.8.21;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { TransferHelper } from "../libraries/TransferHelper.sol";
import { IUniswapV3Pool } from "../interfaces/IUniswapV3Pool.sol";
import { IApproveSwapAndPay } from "../interfaces/abstract/IApproveSwapAndPay.sol";
import { SafeCast } from "../vendor0.8/uniswap/SafeCast.sol";
import "../libraries/ExternalCall.sol";
import "../libraries/ErrLib.sol";

// import "hardhat/console.sol";

abstract contract ApproveSwapAndPay is IApproveSwapAndPay {
    using SafeCast for uint256;
    using TransferHelper for address;
    using { ExternalCall._externalCall } for address;
    using { ExternalCall._readFirstBytes4 } for bytes;
    using { ErrLib.revertError } for bool;

    /// @dev The minimum value that can be returned from #getSqrtRatioAtTick. Equivalent to getSqrtRatioAtTick(MIN_TICK)
    uint160 internal constant MIN_SQRT_RATIO = 4295128739;

    /// @dev The maximum value that can be returned from #getSqrtRatioAtTick. Equivalent to getSqrtRatioAtTick(MAX_TICK)
    uint160 internal constant MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970342;

    address public immutable UNDERLYING_V3_FACTORY_ADDRESS;
    bytes32 public immutable UNDERLYING_V3_POOL_INIT_CODE_HASH;

    ///     swapTarget   => (func.selector => is allowed)
    mapping(address => mapping(bytes4 => bool)) internal whitelistedCall;

    error SwapSlippageCheckError(uint256 expectedOut, uint256 receivedOut);

    constructor(
        address _UNDERLYING_V3_FACTORY_ADDRESS,
        bytes32 _UNDERLYING_V3_POOL_INIT_CODE_HASH
    ) {
        UNDERLYING_V3_FACTORY_ADDRESS = _UNDERLYING_V3_FACTORY_ADDRESS;
        UNDERLYING_V3_POOL_INIT_CODE_HASH = _UNDERLYING_V3_POOL_INIT_CODE_HASH;
    }

    /**
     * @notice Checks if a swap call is whitelisted.
     * @dev Determines if a given `swapTarget` address and function `selector` are whitelisted for swaps.
     * @param swapTarget The address to check if it is a whitelisted destination for a swap call.
     * @param selector The function selector to check if it is whitelisted for calls to the `swapTarget`.
     * @return IsWhitelisted Returns `true` if the `swapTarget` address and `selector` combination is whitelisted, otherwise `false`.
     */
    function swapIsWhitelisted(
        address swapTarget,
        bytes4 selector
    ) external view returns (bool IsWhitelisted) {
        IsWhitelisted = whitelistedCall[swapTarget][selector];
    }

    /**
     * @dev This internal function attempts to approve a specific amount of tokens for a spender.
     * It performs a call to the `approve` function on the token contract using the provided parameters,
     * and returns a boolean indicating whether the approval was successful or not.
     * @param token The address of the token contract.
     * @param spender The address of the spender.
     * @param amount The amount of tokens to be approved.
     * @return A boolean indicating whether the approval was successful or not.
     */
    function _tryApprove(address token, address spender, uint256 amount) private returns (bool) {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.approve.selector, spender, amount)
        );
        return success && (data.length == 0 || abi.decode(data, (bool)));
    }

    /**
     * @dev This internal function ensures that the allowance for a spender is at least the specified amount.
     * If the current allowance is less than the specified amount, it attempts to approve the maximum possible value,
     * and if that fails, it retries with the maximum possible value minus one. If both attempts fail,
     * it reverts with an error indicating that the approval did not succeed.
     * @param token The address of the token contract.
     * @param spender The address of the spender.
     * @param amount The minimum required allowance.
     */
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

    /**
     * @dev This internal view function retrieves the balance of the contract for a specific token.
     * It performs a staticcall to the `balanceOf` function on the token contract using the provided parameter,
     * and returns the balance as a uint256 value.
     * @param token The address of the token contract.
     * @return balance The balance of the contract for the specified token.
     */
    function _getBalance(address token) internal view returns (uint256 balance) {
        balance = token.getBalance();
    }

    /**
     * @dev Retrieves the balance of two tokens in the contract.
     * @param tokenA The address of the first token.
     * @param tokenB The address of the second token.
     * @return balanceA The balance of the first token in the contract.
     * @return balanceB The balance of the second token in the contract.
     */
    function _getPairBalance(
        address tokenA,
        address tokenB
    ) internal view returns (uint256 balanceA, uint256 balanceB) {
        balanceA = tokenA.getBalance();
        balanceB = tokenB.getBalance();
    }

    /**
     * @dev Performs a series of external swap calls as defined by the `externalSwap` parameter.
     * It iterates through an array of `SwapParams`, executing each corresponding swap.
     *
     * Emits a revert with specific error code if:
     * - The swap target is not whitelisted for the specified function selector.
     * - The external swap call is unsuccessful.
     *
     * @param tokenIn The address of the input token that will be swapped.
     * @param externalSwap An array of `SwapParams` containing the targets, gas limits,
     *                     and data for each external swap call.
     */
    function _callExternalSwap(address tokenIn, SwapParams[] calldata externalSwap) internal {
        for (uint256 i = 0; i < externalSwap.length; ) {
            (address swapTarget, uint256 maxGasForCall, bytes calldata swapData) = (
                externalSwap[i].swapTarget,
                externalSwap[i].maxGasForCall,
                externalSwap[i].swapData
            );
            (swapTarget == address(0)).revertError(ErrLib.ErrorCode.SWAP_TARGET_ADDRESS_IS_ZERO);
            bytes4 funcSelector = swapData._readFirstBytes4();
            // Verifying if the swap target is whitelisted for the specified function selector
            (!whitelistedCall[swapTarget][funcSelector]).revertError(
                ErrLib.ErrorCode.SWAP_TARGET_NOT_APPROVED
            );
            // Maximizing approval if necessary
            _maxApproveIfNecessary(tokenIn, swapTarget, type(uint128).max);

            // calling the external swap
            bool success = swapTarget._externalCall(swapData, maxGasForCall);
            (!success).revertError(ErrLib.ErrorCode.INVALID_SWAP);
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev Transfers a specified amount of tokens from the `payer` to the `recipient`.
     * @param token The address of the token to be transferred.
     * @param payer The address from which the tokens will be transferred.
     * @param recipient The address that will receive the tokens.
     * @param value The amount of tokens to be transferred.
     * @notice If the specified `value` is greater than zero, this function will transfer the tokens either by calling `safeTransfer`
     * if the `payer` is equal to `address(this)`, or by calling `safeTransferFrom` otherwise.
     */
    function _pay(address token, address payer, address recipient, uint256 value) internal {
        if (value > 0) {
            if (payer == address(this)) {
                token.safeTransfer(recipient, value);
            } else {
                token.safeTransferFrom(payer, recipient, value);
            }
        }
    }

    /**
     * @dev Performs a token swap using Uniswap V3 with exact input.
     * @param params The struct containing all swap parameters.
     * @return amountOut The amount of tokens received as output from the swap.
     * @notice This internal function swaps the exact amount of `params.amountIn` tokens from `params.tokenIn` to `params.tokenOut`.
     * The swapped amount is calculated based on the current pool ratio between `params.tokenIn` and `params.tokenOut`.
     */
    function _v3SwapExactInput(
        v3SwapExactInputParams memory params
    ) internal returns (uint256 amountOut) {
        // fee must be non-zero
        (params.fee == 0).revertError(ErrLib.ErrorCode.INTERNAL_SWAP_POOL_REQUIRED);
        // Determine if tokenIn has a 0th token
        bool zeroForTokenIn = params.tokenIn < params.tokenOut;
        // Compute the address of the Uniswap V3 pool based on tokenIn, tokenOut, and fee
        // Call the swap function on the Uniswap V3 pool contract
        (int256 amount0Delta, int256 amount1Delta) = IUniswapV3Pool(
            computePoolAddress(params.tokenIn, params.tokenOut, params.fee)
        ).swap(
                address(this), //recipient
                zeroForTokenIn,
                params.amountIn.toInt256(),
                zeroForTokenIn ? MIN_SQRT_RATIO + 1 : MAX_SQRT_RATIO - 1,
                abi.encode(params.fee, params.tokenIn, params.tokenOut)
            );
        // Calculate the actual amount of output tokens received
        amountOut = uint256(-(zeroForTokenIn ? amount1Delta : amount0Delta));
    }

    /**
     * @dev Callback function invoked by Uniswap V3 swap.
     *
     * This function is called when a swap is executed on a Uniswap V3 pool. It performs the necessary validations
     * and payment processing.
     *
     * Requirements:
     * - The swap must not entirely fall within 0-liquidity regions, as it is not supported.
     * - The caller must be the expected Uniswap V3 pool contract.
     *
     * @param amount0Delta The change in token0 balance resulting from the swap.
     * @param amount1Delta The change in token1 balance resulting from the swap.
     * @param data Additional data required for processing the swap, encoded as `(uint24, address, address)`.
     */
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

    /**
     * @dev Computes the address of a Uniswap V3 pool based on the provided parameters.
     *
     * This function calculates the address of a Uniswap V3 pool contract using the token addresses and fee.
     * It follows the same logic as Uniswap's pool initialization process.
     *
     * @param tokenA The address of one of the tokens in the pair.
     * @param tokenB The address of the other token in the pair.
     * @param fee The fee level of the pool.
     * @return pool The computed address of the Uniswap V3 pool.
     */
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
