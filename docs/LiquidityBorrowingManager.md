# LiquidityBorrowingManager



> LiquidityBorrowingManager





## Methods

### UNDERLYING_V3_FACTORY_ADDRESS

```solidity
function UNDERLYING_V3_FACTORY_ADDRESS() external view returns (address)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### UNDERLYING_V3_POOL_INIT_CODE_HASH

```solidity
function UNDERLYING_V3_POOL_INIT_CODE_HASH() external view returns (bytes32)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bytes32 | undefined |

### VAULT_ADDRESS

```solidity
function VAULT_ADDRESS() external view returns (address)
```

The address of the vault contract.




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### borrow

```solidity
function borrow(ILiquidityBorrowingManager.BorrowParams params, uint256 deadline) external nonpayable returns (uint256, uint256, uint256, uint256, uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| params | ILiquidityBorrowingManager.BorrowParams | undefined |
| deadline | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |
| _1 | uint256 | undefined |
| _2 | uint256 | undefined |
| _3 | uint256 | undefined |
| _4 | uint256 | undefined |

### borrowingsInfo

```solidity
function borrowingsInfo(bytes32) external view returns (address borrower, address saleToken, address holdToken, uint256 borrowedAmount, uint256 liquidationBonus, uint256 accLoanRatePerSeconds, uint256 dailyRateCollateralBalance)
```

borrowingKey=&gt;BorrowingInfo



#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | bytes32 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| borrower | address | undefined |
| saleToken | address | undefined |
| holdToken | address | undefined |
| borrowedAmount | uint256 | undefined |
| liquidationBonus | uint256 | undefined |
| accLoanRatePerSeconds | uint256 | undefined |
| dailyRateCollateralBalance | uint256 | undefined |

### calculateCollateralAmtForLifetime

```solidity
function calculateCollateralAmtForLifetime(bytes32 borrowingKey, uint256 lifetimeInSeconds) external view returns (uint256 collateralAmt)
```



*Calculates the collateral amount required for a lifetime in seconds.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| borrowingKey | bytes32 | The unique identifier of the borrowing. |
| lifetimeInSeconds | uint256 | The duration of the borrowing in seconds. |

#### Returns

| Name | Type | Description |
|---|---|---|
| collateralAmt | uint256 | The calculated collateral amount that is needed. |

### checkDailyRateCollateral

```solidity
function checkDailyRateCollateral(bytes32 borrowingKey) external view returns (int256 balance, uint256 estimatedLifeTime)
```

This function is used to check the daily rate collateral for a specific borrowing.



#### Parameters

| Name | Type | Description |
|---|---|---|
| borrowingKey | bytes32 | The key of the borrowing. |

#### Returns

| Name | Type | Description |
|---|---|---|
| balance | int256 | The balance of the daily rate collateral. |
| estimatedLifeTime | uint256 | The estimated lifetime of the collateral in seconds. |

### collectLoansFees

```solidity
function collectLoansFees(address[] tokens) external nonpayable
```

This function allows the caller to collect their own loan fees for multiple tokens and transfer them to themselves.



#### Parameters

| Name | Type | Description |
|---|---|---|
| tokens | address[] | An array of addresses representing the tokens for which fees will be collected. |

### collectProtocol

```solidity
function collectProtocol(address recipient, address[] tokens) external nonpayable
```

This function allows the owner to collect protocol fees for multiple tokens and transfer them to a specified recipient.

*Only the contract owner can call this function.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| recipient | address | The address of the recipient who will receive the collected fees. |
| tokens | address[] | An array of addresses representing the tokens for which fees will be collected. |

### computePoolAddress

```solidity
function computePoolAddress(address tokenA, address tokenB, uint24 fee) external view returns (address pool)
```



*Computes the address of a Uniswap V3 pool based on the provided parameters. This function calculates the address of a Uniswap V3 pool contract using the token addresses and fee. It follows the same logic as Uniswap&#39;s pool initialization process.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| tokenA | address | The address of one of the tokens in the pair. |
| tokenB | address | The address of the other token in the pair. |
| fee | uint24 | The fee level of the pool. |

#### Returns

| Name | Type | Description |
|---|---|---|
| pool | address | The computed address of the Uniswap V3 pool. |

### dafaultLiquidationBonusBP

```solidity
function dafaultLiquidationBonusBP() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### flashLoanAggregatorAddress

```solidity
function flashLoanAggregatorAddress() external view returns (address)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### getBorrowerDebtsInfo

```solidity
function getBorrowerDebtsInfo(address borrower) external view returns (struct ILiquidityBorrowingManager.BorrowingInfoExt[] extinfo)
```

Retrieves the debts information for a specific borrower.



#### Parameters

| Name | Type | Description |
|---|---|---|
| borrower | address | The address of the borrower. |

#### Returns

| Name | Type | Description |
|---|---|---|
| extinfo | ILiquidityBorrowingManager.BorrowingInfoExt[] | An array of BorrowingInfoExt structs representing the borrowing information. |

### getBorrowingKeysForBorrower

```solidity
function getBorrowingKeysForBorrower(address borrower) external view returns (bytes32[] borrowingKeys)
```



*Retrieves the borrowing keys for a specific borrower.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| borrower | address | The address of the borrower. |

#### Returns

| Name | Type | Description |
|---|---|---|
| borrowingKeys | bytes32[] | An array of borrowing keys. |

### getBorrowingKeysForTokenId

```solidity
function getBorrowingKeysForTokenId(uint256 tokenId) external view returns (bytes32[] borrowingKeys)
```



*Retrieves the borrowing keys associated with a token ID.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| tokenId | uint256 | The identifier of the token. |

#### Returns

| Name | Type | Description |
|---|---|---|
| borrowingKeys | bytes32[] | An array of borrowing keys. |

### getFeesInfo

```solidity
function getFeesInfo(address feesOwner, address[] tokens) external view returns (uint256[] fees)
```



*Returns the fees information for multiple tokens in an array.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| feesOwner | address | The address of the owner of the fees. |
| tokens | address[] | An array of token addresses for which the fees are to be retrieved. |

#### Returns

| Name | Type | Description |
|---|---|---|
| fees | uint256[] | An array containing the fees for each token. |

### getHoldTokenInfo

```solidity
function getHoldTokenInfo(address saleToken, address holdToken) external view returns (struct IDailyRateAndCollateral.TokenInfo holdTokenRateInfo)
```



*Returns the current daily rate for holding token.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| saleToken | address | The address of the token being sold. |
| holdToken | address | The address of the token being held. |

#### Returns

| Name | Type | Description |
|---|---|---|
| holdTokenRateInfo | IDailyRateAndCollateral.TokenInfo | The structured data containing detailed information for the hold token. |

### getLenderCreditsInfo

```solidity
function getLenderCreditsInfo(uint256 tokenId) external view returns (struct ILiquidityBorrowingManager.BorrowingInfoExt[] extinfo)
```

Retrieves the borrowing information for a specific NonfungiblePositionManager tokenId.



#### Parameters

| Name | Type | Description |
|---|---|---|
| tokenId | uint256 | The unique identifier of the PositionManager token. |

#### Returns

| Name | Type | Description |
|---|---|---|
| extinfo | ILiquidityBorrowingManager.BorrowingInfoExt[] | An array of BorrowingInfoExt structs representing the borrowing information. |

### getLiquidationBonus

```solidity
function getLiquidationBonus(address token, uint256 borrowedAmount, uint256 times) external view returns (uint256 liquidationBonus)
```



*Calculates the liquidation bonus for a given token, borrowed amount, and times factor.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| token | address | The address of the token. |
| borrowedAmount | uint256 | The amount of tokens borrowed. |
| times | uint256 | The times factor to apply to the liquidation bonus calculation. |

#### Returns

| Name | Type | Description |
|---|---|---|
| liquidationBonus | uint256 | The calculated liquidation bonus. |

### getLoansInfo

```solidity
function getLoansInfo(bytes32 borrowingKey) external view returns (struct ILiquidityManager.LoanInfo[] loans)
```

Get information about loans associated with a borrowing key

*This function retrieves an array of loan information for a given borrowing key. The loans are stored in the loansInfo mapping, which is a mapping of borrowing keys to LoanInfo arrays.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| borrowingKey | bytes32 | The unique key associated with the borrowing |

#### Returns

| Name | Type | Description |
|---|---|---|
| loans | ILiquidityManager.LoanInfo[] | An array containing LoanInfo structs representing the loans associated with the borrowing key |

### getPlatformFeesInfo

```solidity
function getPlatformFeesInfo(address[] tokens) external view returns (uint256[] fees)
```



*Get the platform fees information for a list of tokens. This function returns an array of fees corresponding to the list of input tokens provided. Each fee is retrieved from the `platformsFeesInfo` mapping which stores the fee for each token address.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| tokens | address[] | An array of token addresses for which to retrieve the fees information. |

#### Returns

| Name | Type | Description |
|---|---|---|
| fees | uint256[] | Returns an array of fees, one per each token given as input in the same order. |

### harvest

```solidity
function harvest(bytes32 borrowingKey) external nonpayable returns (uint256 harvestedAmt)
```

Allows lenders to harvest the fees accumulated from their loans.

*Retrieves and updates fee amounts for all loans associated with a borrowing position. The function iterates through each loan, calculating and updating the amount of fees due. Requirements: - The borrowingKey must correspond to an active and valid borrowing position. - The collateral balance must be above zero or the current fees must be above the minimum required amount.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| borrowingKey | bytes32 | The unique identifier for the specific borrowing position. |

#### Returns

| Name | Type | Description |
|---|---|---|
| harvestedAmt | uint256 | The total amount of fees harvested by the borrower. |

### increaseCollateralBalance

```solidity
function increaseCollateralBalance(bytes32 borrowingKey, uint256 collateralAmt, uint256 deadline) external nonpayable
```

This function is used to increase the daily rate collateral for a specific borrowing.



#### Parameters

| Name | Type | Description |
|---|---|---|
| borrowingKey | bytes32 | The unique identifier of the borrowing. |
| collateralAmt | uint256 | The amount of collateral to be added. |
| deadline | uint256 | The deadline timestamp after which the transaction is considered invalid. |

### lightQuoterV3Address

```solidity
function lightQuoterV3Address() external view returns (address)
```

The Quoter contract.




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### liquidationBonusForToken

```solidity
function liquidationBonusForToken(address) external view returns (uint256 bonusBP, uint256 minBonusAmount)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| bonusBP | uint256 | undefined |
| minBonusAmount | uint256 | undefined |

### operator

```solidity
function operator() external view returns (address)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### owner

```solidity
function owner() external view returns (address)
```



*Returns the address of the current owner.*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### platformFeesBP

```solidity
function platformFeesBP() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### renounceOwnership

```solidity
function renounceOwnership() external nonpayable
```



*Leaves the contract without owner. It will not be possible to call `onlyOwner` functions. Can only be called by the current owner. NOTE: Renouncing ownership will leave the contract without an owner, thereby disabling any functionality that is only available to the owner.*


### repay

```solidity
function repay(ILiquidityBorrowingManager.RepayParams params, uint256 deadline) external nonpayable returns (uint256 saleTokenOut, uint256 holdTokenOut)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| params | ILiquidityBorrowingManager.RepayParams | undefined |
| deadline | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| saleTokenOut | uint256 | undefined |
| holdTokenOut | uint256 | undefined |

### setSwapCallToWhitelist

```solidity
function setSwapCallToWhitelist(address swapTarget, bytes4 funcSelector, bool isAllowed) external nonpayable
```



*Adds or removes a swap call params to the whitelist.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| swapTarget | address | The address of the target contract for the swap call. |
| funcSelector | bytes4 | The function selector of the swap call. |
| isAllowed | bool | A boolean indicating whether the swap call is allowed or not. |

### swapIsWhitelisted

```solidity
function swapIsWhitelisted(address swapTarget, bytes4 selector) external view returns (bool IsWhitelisted)
```

Checks if a swap call is whitelisted.

*Determines if a given `swapTarget` address and function `selector` are whitelisted for swaps.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| swapTarget | address | The address to check if it is a whitelisted destination for a swap call. |
| selector | bytes4 | The function selector to check if it is whitelisted for calls to the `swapTarget`. |

#### Returns

| Name | Type | Description |
|---|---|---|
| IsWhitelisted | bool | Returns `true` if the `swapTarget` address and `selector` combination is whitelisted, otherwise `false`. |

### transferOwnership

```solidity
function transferOwnership(address newOwner) external nonpayable
```



*Transfers ownership of the contract to a new account (`newOwner`). Can only be called by the current owner.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| newOwner | address | undefined |

### underlyingPositionManager

```solidity
function underlyingPositionManager() external view returns (contract INonfungiblePositionManager)
```

The Nonfungible Position Manager contract.




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract INonfungiblePositionManager | undefined |

### uniswapV3SwapCallback

```solidity
function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes data) external nonpayable
```



*Callback function invoked by Uniswap V3 swap. This function is called when a swap is executed on a Uniswap V3 pool. It performs the necessary validations and payment processing. Requirements: - The swap must not entirely fall within 0-liquidity regions, as it is not supported. - The caller must be the expected Uniswap V3 pool contract.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| amount0Delta | int256 | The change in token0 balance resulting from the swap. |
| amount1Delta | int256 | The change in token1 balance resulting from the swap. |
| data | bytes | Additional data required for processing the swap, encoded as `(uint24, address, address)`. |

### updateHoldTokenDailyRate

```solidity
function updateHoldTokenDailyRate(address saleToken, address holdToken, uint256 value) external nonpayable
```

This function is used to update the daily rate for holding token for specific pair.

*Only the daily rate operator can call this function.The value must be within the range of MIN_DAILY_RATE and MAX_DAILY_RATE.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| saleToken | address | The address of the sale token. |
| holdToken | address | The address of the hold token. |
| value | uint256 | The new value of the daily rate for the hold token will be calculated based on the volatility of the pair and the popularity of loans in it |

### updateHoldTokenEntranceFee

```solidity
function updateHoldTokenEntranceFee(address saleToken, address holdToken, uint256 value) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| saleToken | address | undefined |
| holdToken | address | undefined |
| value | uint256 | undefined |

### updateSettings

```solidity
function updateSettings(enum IOwnerSettings.ITEM _item, uint256[] values) external nonpayable
```

This external function is used to update the settings for a particular item. The function requires two parameters: `_item`, which is the item to be updated, and `values`, which is an array of values containing the new settings. Only the owner of the contract has the permission to call this function.

*Can only be called by the owner of the contract.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _item | enum IOwnerSettings.ITEM | The item to update the settings for. |
| values | uint256[] | An array of values containing the new settings. |

### wagmiLeverageFlashCallback

```solidity
function wagmiLeverageFlashCallback(uint256 bodyAmt, uint256 feeAmt, bytes data) external nonpayable
```



*Executes a flash loan callback function for the Wagmi Leverage protocol. It performs various operations based on the received flash loan data. If the sale token balance is insufficient, it initiates a flash loan to borrow the required amount. Otherwise, it increases liquidity and performs token swaps. Finally, it charges platform fees and makes payments to the vault and flash loan aggregator contracts.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| bodyAmt | uint256 | The amount of the flash loan body token. |
| feeAmt | uint256 | The amount of the flash loan fee token. |
| data | bytes | The encoded flash loan callback data. |



## Events

### Borrow

```solidity
event Borrow(address borrower, bytes32 borrowingKey, uint256 borrowedAmount, uint256 borrowingCollateral, uint256 liquidationBonus, uint256 dailyRatePrepayment, uint256 holdTokenEntranceFee)
```

Indicates that a borrower has made a new loan



#### Parameters

| Name | Type | Description |
|---|---|---|
| borrower  | address | undefined |
| borrowingKey  | bytes32 | undefined |
| borrowedAmount  | uint256 | undefined |
| borrowingCollateral  | uint256 | undefined |
| liquidationBonus  | uint256 | undefined |
| dailyRatePrepayment  | uint256 | undefined |
| holdTokenEntranceFee  | uint256 | undefined |

### CollectLoansFees

```solidity
event CollectLoansFees(address recipient, address[] tokens, uint256[] amounts)
```

Indicates that the lender has collected fee tokens



#### Parameters

| Name | Type | Description |
|---|---|---|
| recipient  | address | undefined |
| tokens  | address[] | undefined |
| amounts  | uint256[] | undefined |

### CollectProtocol

```solidity
event CollectProtocol(address recipient, address[] tokens, uint256[] amounts)
```

Indicates that the protocol has collected fee tokens



#### Parameters

| Name | Type | Description |
|---|---|---|
| recipient  | address | undefined |
| tokens  | address[] | undefined |
| amounts  | uint256[] | undefined |

### EmergencyLoanClosure

```solidity
event EmergencyLoanClosure(address borrower, address lender, bytes32 borrowingKey)
```

Indicates that a loan has been closed due to an emergency situation



#### Parameters

| Name | Type | Description |
|---|---|---|
| borrower  | address | undefined |
| lender  | address | undefined |
| borrowingKey  | bytes32 | undefined |

### Harvest

```solidity
event Harvest(bytes32 borrowingKey, uint256 harvestedAmt)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| borrowingKey  | bytes32 | undefined |
| harvestedAmt  | uint256 | undefined |

### IncreaseCollateralBalance

```solidity
event IncreaseCollateralBalance(address borrower, bytes32 borrowingKey, uint256 collateralAmt)
```

Indicates that a borrower has increased their collateral balance for a loan



#### Parameters

| Name | Type | Description |
|---|---|---|
| borrower  | address | undefined |
| borrowingKey  | bytes32 | undefined |
| collateralAmt  | uint256 | undefined |

### OwnershipTransferred

```solidity
event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| previousOwner `indexed` | address | undefined |
| newOwner `indexed` | address | undefined |

### Repay

```solidity
event Repay(address borrower, address liquidator, bytes32 borrowingKey)
```

Indicates that a borrower has repaid their loan, optionally with the help of a liquidator



#### Parameters

| Name | Type | Description |
|---|---|---|
| borrower  | address | undefined |
| liquidator  | address | undefined |
| borrowingKey  | bytes32 | undefined |

### UpdateHoldTokeEntranceFee

```solidity
event UpdateHoldTokeEntranceFee(address saleToken, address holdToken, uint256 value)
```

Indicates that the entrance fee for holding token(for specific pair) has been updated



#### Parameters

| Name | Type | Description |
|---|---|---|
| saleToken  | address | undefined |
| holdToken  | address | undefined |
| value  | uint256 | undefined |

### UpdateHoldTokenDailyRate

```solidity
event UpdateHoldTokenDailyRate(address saleToken, address holdToken, uint256 value)
```

Indicates that the daily interest rate for holding token(for specific pair) has been updated



#### Parameters

| Name | Type | Description |
|---|---|---|
| saleToken  | address | undefined |
| holdToken  | address | undefined |
| value  | uint256 | undefined |

### UpdateSettingsByOwner

```solidity
event UpdateSettingsByOwner(enum IOwnerSettings.ITEM _item, uint256[] values)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _item  | enum IOwnerSettings.ITEM | undefined |
| values  | uint256[] | undefined |



## Errors

### InvalidLiquidityAmount

```solidity
error InvalidLiquidityAmount(uint256 tokenId, uint128 max, uint128 min, uint128 liquidity)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| tokenId | uint256 | undefined |
| max | uint128 | undefined |
| min | uint128 | undefined |
| liquidity | uint128 | undefined |

### InvalidRestoredLiquidity

```solidity
error InvalidRestoredLiquidity(uint256 tokenId, uint128 borrowedLiquidity, uint128 restoredLiquidity)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| tokenId | uint256 | undefined |
| borrowedLiquidity | uint128 | undefined |
| restoredLiquidity | uint128 | undefined |

### InvalidSettingsValue

```solidity
error InvalidSettingsValue(uint256 value)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| value | uint256 | undefined |

### InvalidTick

```solidity
error InvalidTick()
```

Thrown when the tick passed to #getSqrtRatioAtTick is not between MIN_TICK and MAX_TICK




### InvalidTokens

```solidity
error InvalidTokens(uint256 tokenId)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| tokenId | uint256 | undefined |

### NotApproved

```solidity
error NotApproved(uint256 tokenId)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| tokenId | uint256 | undefined |

### RevertErrorCode

```solidity
error RevertErrorCode(enum ErrLib.ErrorCode code)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| code | enum ErrLib.ErrorCode | undefined |

### SwapSlippageCheckError

```solidity
error SwapSlippageCheckError(uint256 expectedOut, uint256 receivedOut)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| expectedOut | uint256 | undefined |
| receivedOut | uint256 | undefined |

### TooLittleReceivedError

```solidity
error TooLittleReceivedError(uint256 minOut, uint256 out)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| minOut | uint256 | undefined |
| out | uint256 | undefined |


