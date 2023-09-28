// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;
import "@openzeppelin/contracts/access/Ownable.sol";
import { Constants } from "../libraries/Constants.sol";

abstract contract OwnerSettings is Ownable {
    enum ITEM {
        PLATFORM_FEES_BP,
        LIQUIDATION_BONUS_BP,
        DAILY_RATE_OPERATOR,
        SPECIFIC_TOKEN_LIQUIDATION_BONUS_BP
    }

    address public dailyRateOperator;
    uint256 public platformFeesBP = 1000; // 10 % of daily rate
    uint256[2] public dafaultLiquidationBonusBP = [69, 100]; // 0.69% (per extracted liquidity) 100 tokens minimum
    mapping(address => uint256[2]) public specificTokenLiquidationBonus;

    error InvalidSettingsValue(uint256 value);

    constructor() {
        dailyRateOperator = msg.sender;
    }

    /**
     * @notice Updates the settings for a given item.
     * @dev Can only be called by the owner of the contract.
     * @param _item The item to update the settings for.
     * @param values An array of values containing the new settings.
     */
    function updateSettings(ITEM _item, uint256[] calldata values) external onlyOwner {
        if (_item == ITEM.SPECIFIC_TOKEN_LIQUIDATION_BONUS_BP) {
            require(values.length == 3);
            if (values[1] > Constants.MAX_LIQUIDATION_BONUS) {
                revert InvalidSettingsValue(values[1]);
            }
            specificTokenLiquidationBonus[address(uint160(values[0]))] = [values[1], values[2]];
        } else if (_item == ITEM.DAILY_RATE_OPERATOR) {
            require(values.length == 1);
            dailyRateOperator = address(uint160(values[0]));
        } else {
            if (_item == ITEM.PLATFORM_FEES_BP) {
                require(values.length == 1);
                if (values[0] > Constants.MAX_PLATFORM_FEE) {
                    revert InvalidSettingsValue(values[0]);
                }
                platformFeesBP = values[0];
            } else if (_item == ITEM.LIQUIDATION_BONUS_BP) {
                require(values.length == 2);
                if (values[0] > Constants.MAX_LIQUIDATION_BONUS) {
                    revert InvalidSettingsValue(values[0]);
                }
                dafaultLiquidationBonusBP = [values[0], values[1]];
            }
        }
    }
}
