// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;
import "@openzeppelin/contracts/access/Ownable.sol";
import { Constants } from "../libraries/Constants.sol";

abstract contract OwnerSettings is Ownable {
    enum ITEM {
        PLATFORM_FEES_BP,
        DEFAULT_LIQUIDATION_BONUS,
        DAILY_RATE_OPERATOR,
        LIQUIDATION_BONUS_FOR_TOKEN
    }

    struct Liquidation {
        uint256 bonusBP;
        uint256 minBonusAmount;
    }

    address public dailyRateOperator;
    uint256 public platformFeesBP = 2000; // 20 % of daily rate
    uint256 public dafaultLiquidationBonusBP = 69; // 0.69% (per extracted liquidity)
    mapping(address => Liquidation) public liquidationBonusForToken;

    error InvalidSettingsValue(uint256 value);

    constructor() {
        dailyRateOperator = msg.sender;
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
            } else if (_item == ITEM.DEFAULT_LIQUIDATION_BONUS) {
                require(values.length == 1);
                if (values[0] > Constants.MAX_LIQUIDATION_BONUS) {
                    revert InvalidSettingsValue(values[0]);
                }
                dafaultLiquidationBonusBP = values[0];
            }
        }
    }
}
