// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract AggregatorMock {
    function _safeTransfer(address token, address to, uint256 value) private {
        (bool success, ) = token.call(abi.encodeWithSelector(IERC20.transfer.selector, to, value));
        require(success, "AggregatorMock: safeTransfer failed");
    }

    function _safeTransferFrom(address token, address from, address to, uint256 value) private {
        (bool success, ) = token.call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, value)
        );
        require(success, "AggregatorMock: safeTransferFrom failed");
    }

    function swap(bytes calldata wrappedCallData) external {
        (address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut) = abi.decode(
            wrappedCallData,
            (address, address, uint256, uint256)
        );
        require(tokenIn != tokenOut, "TE");
        _safeTransferFrom(tokenIn, msg.sender, address(this), amountIn);
        _safeTransfer(tokenOut, msg.sender, amountOut);
    }
}
