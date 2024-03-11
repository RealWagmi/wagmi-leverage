// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

interface IOwnerSettings {
    /**
     * @dev Enum representing various items.
     *
     * @param PLATFORM_FEES_BP The percentage of platform fees in basis points.
     * @param DEFAULT_LIQUIDATION_BONUS The default liquidation bonus.
     * @param OPERATOR The operator for operating the daily rate and entrance fee.
     * @param LIQUIDATION_BONUS_FOR_TOKEN The liquidation bonus for a specific token.
     */
    enum ITEM {
        PLATFORM_FEES_BP,
        DEFAULT_LIQUIDATION_BONUS,
        OPERATOR,
        LIQUIDATION_BONUS_FOR_TOKEN,
        FLASH_LOAN_AGGREGATOR,
        LIGHT_QUOTER,
        VAULT_FLASH_FEES
    }
    /**
     * @dev Struct representing liquidation parameters.
     *
     * @param bonusBP The bonus in basis points that will be applied during a liquidation.
     * @param minBonusAmount The minimum amount of bonus that can be applied during a liquidation.
     */
    struct Liquidation {
        uint256 bonusBP;
        uint256 minBonusAmount;
    }

    function updateSettings(ITEM _item, uint256[] calldata values) external;

    function liquidationBonusForToken(
        address
    ) external view returns (uint256 bonusBP, uint256 minBonusAmount);

    function platformFeesBP() external view returns (uint256);

    function dafaultLiquidationBonusBP() external view returns (uint256);

    function operator() external view returns (address);
}
