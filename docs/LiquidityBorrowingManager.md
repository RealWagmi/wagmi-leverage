# LiquidityBorrowingManager



> LiquidityBorrowingManager



*This contract manages the borrowing liquidity functionality for WAGMI Leverage protocol. It inherits from LiquidityManager, OwnerSettings, DailyRateAndCollateral, and ReentrancyGuard contracts.*

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
function borrow(LiquidityBorrowingManager.BorrowParams params, uint256 deadline) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| params | LiquidityBorrowingManager.BorrowParams | undefined |
| deadline | uint256 | undefined |

### borrowingsInfo

```solidity
function borrowingsInfo(bytes32) external view returns (address borrower, address saleToken, address holdToken, uint256 feesOwed, uint256 borrowedAmount, uint256 liquidationBonus, uint256 accLoanRatePerSeconds, uint256 dailyRateCollateralBalance)
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
| feesOwed | uint256 | undefined |
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





#### Parameters

| Name | Type | Description |
|---|---|---|
| tokenA | address | undefined |
| tokenB | address | undefined |
| fee | uint24 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| pool | address | undefined |

### dafaultLiquidationBonusBP

```solidity
function dafaultLiquidationBonusBP() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### dailyRateOperator

```solidity
function dailyRateOperator() external view returns (address)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### getBorrowerDebtsCount

```solidity
function getBorrowerDebtsCount(address borrower) external view returns (uint256 count)
```



*Returns the number of borrowings for a given borrower.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| borrower | address | The address of the borrower. |

#### Returns

| Name | Type | Description |
|---|---|---|
| count | uint256 | The total number of borrowings for the borrower. |

### getBorrowerDebtsInfo

```solidity
function getBorrowerDebtsInfo(address borrower) external view returns (struct LiquidityBorrowingManager.BorrowingInfoExt[] extinfo)
```

Retrieves the debts information for a specific borrower.



#### Parameters

| Name | Type | Description |
|---|---|---|
| borrower | address | The address of the borrower. |

#### Returns

| Name | Type | Description |
|---|---|---|
| extinfo | LiquidityBorrowingManager.BorrowingInfoExt[] | An array of BorrowingInfoExt structs representing the borrowing information. |

### getHoldTokenDailyRateInfo

```solidity
function getHoldTokenDailyRateInfo(address saleToken, address holdToken) external view returns (uint256 currentDailyRate, struct DailyRateAndCollateral.TokenInfo holdTokenRateInfo)
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
| currentDailyRate | uint256 | The current daily rate . |
| holdTokenRateInfo | DailyRateAndCollateral.TokenInfo | undefined |

### getLenderCreditsCount

```solidity
function getLenderCreditsCount(uint256 tokenId) external view returns (uint256 count)
```



*Returns the number of loans associated with a given NonfungiblePositionManager tokenId.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| tokenId | uint256 | The ID of the token. |

#### Returns

| Name | Type | Description |
|---|---|---|
| count | uint256 | The total number of loans associated with the tokenId. |

### getLenderCreditsInfo

```solidity
function getLenderCreditsInfo(uint256 tokenId) external view returns (struct LiquidityBorrowingManager.BorrowingInfoExt[] extinfo)
```

Retrieves the borrowing information for a specific NonfungiblePositionManager tokenId.



#### Parameters

| Name | Type | Description |
|---|---|---|
| tokenId | uint256 | The unique identifier of the PositionManager token. |

#### Returns

| Name | Type | Description |
|---|---|---|
| extinfo | LiquidityBorrowingManager.BorrowingInfoExt[] | An array of BorrowingInfoExt structs representing the borrowing information. |

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
function getLoansInfo(bytes32 borrowingKey) external view returns (struct LiquidityManager.LoanInfo[] loans)
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
| loans | LiquidityManager.LoanInfo[] | An array containing LoanInfo structs representing the loans associated with the borrowing key |

### getPlatformsFeesInfo

```solidity
function getPlatformsFeesInfo(address[] tokens) external view returns (uint256[] fees)
```



*Returns the fees information for multiple tokens in an array.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| tokens | address[] | An array of token addresses for which the fees are to be retrieved. |

#### Returns

| Name | Type | Description |
|---|---|---|
| fees | uint256[] | An array containing the fees for each token. |

### holdTokenInfo

```solidity
function holdTokenInfo(bytes32) external view returns (uint32 latestUpTimestamp, uint256 accLoanRatePerSeconds, uint256 currentDailyRate, uint256 totalBorrowed)
```

pairKey =&gt; TokenInfo



#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | bytes32 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| latestUpTimestamp | uint32 | undefined |
| accLoanRatePerSeconds | uint256 | undefined |
| currentDailyRate | uint256 | undefined |
| totalBorrowed | uint256 | undefined |

### increaseCollateralBalance

```solidity
function increaseCollateralBalance(bytes32 borrowingKey, uint256 collateralAmt) external nonpayable
```

This function is used to increase the daily rate collateral for a specific borrowing.



#### Parameters

| Name | Type | Description |
|---|---|---|
| borrowingKey | bytes32 | The unique identifier of the borrowing. |
| collateralAmt | uint256 | The amount of collateral to be added. |

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

### loansInfo

```solidity
function loansInfo(bytes32, uint256) external view returns (uint128 liquidity, uint256 tokenId)
```

borrowingKey=&gt;LoanInfo



#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | bytes32 | undefined |
| _1 | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| liquidity | uint128 | undefined |
| tokenId | uint256 | undefined |

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
function repay(LiquidityBorrowingManager.RepayParams params, uint256 deadline) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| params | LiquidityBorrowingManager.RepayParams | undefined |
| deadline | uint256 | undefined |

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

### takeOverDebt

```solidity
function takeOverDebt(bytes32 borrowingKey, uint256 collateralAmt) external nonpayable
```

Take over debt by transferring ownership of a borrowing to the current caller

*This function allows the current caller to take over a debt from another borrower. The function validates the borrowingKey and checks if the collateral balance is negative. If the conditions are met, the function transfers ownership of the borrowing to the current caller, updates the daily rate collateral balance, and pays the collateral amount to the vault. Emits a `TakeOverDebt` event.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| borrowingKey | bytes32 | The unique key associated with the borrowing to be taken over |
| collateralAmt | uint256 | The amount of collateral to be provided by the new borrower |

### tokenIdToBorrowingKeys

```solidity
function tokenIdToBorrowingKeys(uint256, uint256) external view returns (bytes32)
```

NonfungiblePositionManager tokenId =&gt; BorrowingKeys[]



#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |
| _1 | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bytes32 | undefined |

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

### underlyingQuoterV2

```solidity
function underlyingQuoterV2() external view returns (contract IQuoterV2)
```

The QuoterV2 contract.




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract IQuoterV2 | undefined |

### uniswapV3SwapCallback

```solidity
function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes data) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| amount0Delta | int256 | undefined |
| amount1Delta | int256 | undefined |
| data | bytes | undefined |

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

### updateSettings

```solidity
function updateSettings(enum OwnerSettings.ITEM _item, uint256[] values) external nonpayable
```

This external function is used to update the settings for a particular item. The function requires two parameters: `_item`, which is the item to be updated, and `values`, which is an array of values containing the new settings. Only the owner of the contract has the permission to call this function.

*Can only be called by the owner of the contract.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _item | enum OwnerSettings.ITEM | The item to update the settings for. |
| values | uint256[] | An array of values containing the new settings. |

### userBorrowingKeys

```solidity
function userBorrowingKeys(address, uint256) external view returns (bytes32)
```

borrower =&gt; BorrowingKeys[]



#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |
| _1 | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bytes32 | undefined |

### whitelistedCall

```solidity
function whitelistedCall(address, bytes4) external view returns (bool)
```

swapTarget   =&gt; (func.selector =&gt; is allowed)



#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |
| _1 | bytes4 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |



## Events

### Borrow

```solidity
event Borrow(address borrower, bytes32 borrowingKey, uint256 borrowedAmount, uint256 borrowingCollateral, uint256 liquidationBonus, uint256 dailyRatePrepayment)
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

### TakeOverDebt

```solidity
event TakeOverDebt(address oldBorrower, address newBorrower, bytes32 oldBorrowingKey, bytes32 newBorrowingKey)
```

Indicates that a new borrower has taken over the debt from an old borrower



#### Parameters

| Name | Type | Description |
|---|---|---|
| oldBorrower  | address | undefined |
| newBorrower  | address | undefined |
| oldBorrowingKey  | bytes32 | undefined |
| newBorrowingKey  | bytes32 | undefined |

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



## Errors

### InvalidBorrowedLiquidity

```solidity
error InvalidBorrowedLiquidity(uint256 tokenId)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| tokenId | uint256 | undefined |

### InvalidRestoredLiquidity

```solidity
error InvalidRestoredLiquidity(uint256 tokenId, uint128 borrowedLiquidity, uint128 restoredLiquidity, uint256 amount0, uint256 amount1, uint256 holdTokentBalance, uint256 saleTokenBalance)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| tokenId | uint256 | undefined |
| borrowedLiquidity | uint128 | undefined |
| restoredLiquidity | uint128 | undefined |
| amount0 | uint256 | undefined |
| amount1 | uint256 | undefined |
| holdTokentBalance | uint256 | undefined |
| saleTokenBalance | uint256 | undefined |

### InvalidSettingsValue

```solidity
error InvalidSettingsValue(uint256 value)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| value | uint256 | undefined |

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

### TooLittleBorrowedLiquidity

```solidity
error TooLittleBorrowedLiquidity(uint128 liquidity)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| liquidity | uint128 | undefined |

### TooLittleReceivedError

```solidity
error TooLittleReceivedError(uint256 minOut, uint256 out)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| minOut | uint256 | undefined |
| out | uint256 | undefined |


