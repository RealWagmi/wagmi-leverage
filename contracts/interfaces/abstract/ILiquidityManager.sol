// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "../INonfungiblePositionManager.sol";
import "../ILightQuoterV3.sol";

interface ILiquidityManager {
    /**
     * @notice Represents information about a loan.
     * @dev This struct is used to store liquidity and tokenId for a loan.
     * @param liquidity The amount of liquidity for the loan represented by a uint128 value.
     * @param tokenId The token ID associated with the loan represented by a uint256 value.
     */
    struct LoanInfo {
        uint128 liquidity;
        uint256 tokenId;
    }

    struct Amounts {
        uint256 amount0;
        uint256 amount1;
    }

    struct SqrtPriceLimitation {
        uint24 feeTier;
        uint160 sqrtPriceLimitX96;
    }

    /// @dev Struct containing parameters necessary for conducting a flash loan.
    /// @param protocol The identifier of the flash loan protocol (if 0, the flash loan is not used).
    /// @param data Arbitrary data that can be used by the flash loan protocol.
    struct FlashLoanParams {
        uint8 protocol;
        bytes data;
    }

    /// @dev Struct containing parameters for defining restoration routes,
    /// including the use of external swaps, fee tiers for internal swaps, and potential flash loan arrangements.
    /// @param strict  If the flag strict is false, part of the profit or liquidation bonus can be used to close the position.
    /// @param tokenId The ID of the NFT-POS token that needs to be restored, if applicable.
    /// @param flashLoanParams An array of FlashLoanParams structs, detailing each flash loan involved in the route.
    struct FlashLoanRoutes {
        bool strict;
        FlashLoanParams[] flashLoanParams;
    }
    /**
     * @notice Contains parameters for restoring liquidity.
     * @dev This struct is used to store various parameters required for restoring liquidity.
     * @param zeroForSaleToken A boolean value indicating whether the token for sale is the 0th token or not.
     * @param totalfeesOwed The total fees owed represented by a uint256 value.
     * @param totalBorrowedAmount The total borrowed amount represented by a uint256 value.
     * @param routes An array of FlashLoanRoutes structs representing the restoration routes.
     * @param loans An array of LoanInfo structs representing the loans.
     */
    struct RestoreLiquidityParams {
        bool zeroForSaleToken;
        uint256 totalfeesOwed;
        uint256 totalBorrowedAmount;
        FlashLoanRoutes routes;
        LoanInfo[] loans;
    }

    struct CallbackData {
        bool zeroForSaleToken;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        address saleToken;
        address holdToken;
        uint256 holdTokenDebt;
        uint256 vaultBodyDebt;
        uint256 vaultFeeDebt;
        Amounts amounts;
        LoanInfo loan;
        FlashLoanRoutes routes;
    }
    /**
     * @title NFT Position Cache Data Structure
     * @notice This struct holds the cache data necessary for restoring liquidity to an NFT position.
     * @dev Stores essential parameters for an NFT representing a position in a Uniswap-like pool.
     * @param tickLower The lower bound of the liquidity position's price range, represented as an int24.
     * @param tickUpper The upper bound of the liquidity position's price range, represented as an int24.
     * @param fee The fee tier of the Uniswap pool in which this liquidity will be restored, represented as a uint24.
     * @param liquidity The amount of NFT Position liquidity.
     * @param saleToken The ERC-20 sale token.
     * @param holdToken The ERC-20 hold token.
     * @param operator The address of the operator who is permitted to restore liquidity and manage this position.
     * @param holdTokenDebt The outstanding debt of the hold token that needs to be repaid when liquidity is restored, represented as a uint256.
     */
    struct NftPositionCache {
        int24 tickLower;
        int24 tickUpper;
        uint24 fee;
        uint128 liquidity;
        address saleToken;
        address holdToken;
        address operator;
        uint256 holdTokenDebt;
    }

    function VAULT_ADDRESS() external view returns (address);

    function underlyingPositionManager() external view returns (INonfungiblePositionManager);

    function lightQuoterV3Address() external view returns (address);

    function flashLoanAggregatorAddress() external view returns (address);
}
