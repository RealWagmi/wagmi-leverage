// SPDX-License-Identifier: SAL-1.0
pragma solidity 0.8.23;
import "@openzeppelin/contracts/access/Ownable.sol";
import { Constants } from "../libraries/Constants.sol";
import "../interfaces/abstract/IOwnerSettings.sol";
import "./LiquidityManager.sol";

abstract contract OwnerSettings is Ownable, LiquidityManager, IOwnerSettings {
    /**
     * @dev Address of the daily rate operator.
     */
    address public operator;
    /**
     * @dev Platform fees in basis points.
     * 2000 BP represents a 20% fee on the daily rate.
     */
    uint256 public platformFeesBP = 2000;
    /**
     * @dev Default liquidation bonus in basis points.
     * 69 BP represents a 1.5% bonus per extracted liquidity.
     */
    uint256 public dafaultLiquidationBonusBP = 150;
    /**
     * @dev Mapping to store liquidation bonuses for each token address.
     * The keys are token addresses and values are instances of the `Liquidation` struct.
     */
    mapping(address => Liquidation) public liquidationBonusForToken;

    event UpdateSettingsByOwner(ITEM _item, uint256[] values);

    error InvalidSettingsValue(uint256 value);

    constructor() {
        operator = msg.sender;
    }

    /**
     * @notice This external function is used to update the settings for a particular item. The function requires two parameters: `_item`,
     * which is the item to be updated, and `values`, which is an array of values containing the new settings.
     * Only the owner of the contract has the permission to call this function.
     * @dev Can only be called by the owner of the contract.
     * @param _item The item to update the settings for.
     * @param values An array of values containing the new settings.
     */
    function updateSettings(ITEM _item, uint256[] calldata values) external onlyOwner {
        if (_item == ITEM.LIQUIDATION_BONUS_FOR_TOKEN) {
            require(values.length == 3);
            if (values[1] > Constants.MAX_LIQUIDATION_BONUS) {
                revert InvalidSettingsValue(values[1]);
            }
            if (values[2] == 0) {
                revert InvalidSettingsValue(0);
            }
            liquidationBonusForToken[address(uint160(values[0]))] = Liquidation(
                values[1],
                values[2]
            );
        } else if (_item == ITEM.VAULT_FLASH_FEES) {
            require(values.length == 2);
            Vault(VAULT_ADDRESS).setFlashFee(address(uint160(values[0])), uint24(values[1]));
        } else {
            require(values.length == 1);
            if (_item == ITEM.PLATFORM_FEES_BP) {
                if (values[0] > Constants.MAX_PLATFORM_FEE) {
                    revert InvalidSettingsValue(values[0]);
                }
                platformFeesBP = values[0];
            } else if (_item == ITEM.DEFAULT_LIQUIDATION_BONUS) {
                if (values[0] > Constants.MAX_LIQUIDATION_BONUS) {
                    revert InvalidSettingsValue(values[0]);
                }
                dafaultLiquidationBonusBP = values[0];
            } else if (_item == ITEM.OPERATOR) {
                operator = address(uint160(values[0]));
            } else if (_item == ITEM.FLASH_LOAN_AGGREGATOR) {
                flashLoanAggregatorAddress = address(uint160(values[0]));
            } else if (_item == ITEM.LIGHT_QUOTER) {
                lightQuoterV3Address = address(uint160(values[0]));
            }
        }
        emit UpdateSettingsByOwner(_item, values);
    }
}
