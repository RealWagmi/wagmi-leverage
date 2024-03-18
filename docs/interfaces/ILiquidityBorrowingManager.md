# ILiquidityBorrowingManager









## Methods

### VAULT_ADDRESS

```solidity
function VAULT_ADDRESS() external view returns (address)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### borrow

```solidity
function borrow(ILiquidityBorrowingManager.BorrowParams params, uint256 deadline) external nonpayable returns (uint256 borrowedAmount, uint256 marginDeposit, uint256 liquidationBonus, uint256 dailyRateCollateral, uint256 holdTokenEntranceFee)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| params | ILiquidityBorrowingManager.BorrowParams | undefined |
| deadline | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| borrowedAmount | uint256 | undefined |
| marginDeposit | uint256 | undefined |
| liquidationBonus | uint256 | undefined |
| dailyRateCollateral | uint256 | undefined |
| holdTokenEntranceFee | uint256 | undefined |

### borrowingsInfo

```solidity
function borrowingsInfo(bytes32 borrowingKey) external view returns (address borrower, address saleToken, address holdToken, uint256 borrowedAmount, uint256 liquidationBonus, uint256 accLoanRatePerSeconds, uint256 dailyRateCollateralBalance)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| borrowingKey | bytes32 | undefined |

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





#### Parameters

| Name | Type | Description |
|---|---|---|
| borrowingKey | bytes32 | undefined |
| lifetimeInSeconds | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| collateralAmt | uint256 | undefined |

### checkDailyRateCollateral

```solidity
function checkDailyRateCollateral(bytes32 borrowingKey) external view returns (int256 balance, uint256 estimatedLifeTime)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| borrowingKey | bytes32 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| balance | int256 | undefined |
| estimatedLifeTime | uint256 | undefined |

### collectLoansFees

```solidity
function collectLoansFees(address[] tokens) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| tokens | address[] | undefined |

### collectProtocol

```solidity
function collectProtocol(address recipient, address[] tokens) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| recipient | address | undefined |
| tokens | address[] | undefined |

### computePoolAddress

```solidity
function computePoolAddress(address tokenA, address tokenB, uint24 fee) external view returns (address)
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
| _0 | address | undefined |

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





#### Parameters

| Name | Type | Description |
|---|---|---|
| borrower | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| extinfo | ILiquidityBorrowingManager.BorrowingInfoExt[] | undefined |

### getBorrowingKeysForBorrower

```solidity
function getBorrowingKeysForBorrower(address borrower) external view returns (bytes32[] borrowingKeys)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| borrower | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| borrowingKeys | bytes32[] | undefined |

### getBorrowingKeysForTokenId

```solidity
function getBorrowingKeysForTokenId(uint256 tokenId) external view returns (bytes32[] borrowingKeys)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| tokenId | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| borrowingKeys | bytes32[] | undefined |

### getFeesInfo

```solidity
function getFeesInfo(address feesOwner, address[] tokens) external view returns (uint256[] fees)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| feesOwner | address | undefined |
| tokens | address[] | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| fees | uint256[] | undefined |

### getHoldTokenInfo

```solidity
function getHoldTokenInfo(address saleToken, address holdToken) external view returns (struct IDailyRateAndCollateral.TokenInfo holdTokenRateInfo)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| saleToken | address | undefined |
| holdToken | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| holdTokenRateInfo | IDailyRateAndCollateral.TokenInfo | undefined |

### getLenderCreditsInfo

```solidity
function getLenderCreditsInfo(uint256 tokenId) external view returns (struct ILiquidityBorrowingManager.BorrowingInfoExt[] extinfo)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| tokenId | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| extinfo | ILiquidityBorrowingManager.BorrowingInfoExt[] | undefined |

### getLiquidationBonus

```solidity
function getLiquidationBonus(address token, uint256 borrowedAmount, uint256 times) external view returns (uint256 liquidationBonus)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| token | address | undefined |
| borrowedAmount | uint256 | undefined |
| times | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| liquidationBonus | uint256 | undefined |

### getLoansInfo

```solidity
function getLoansInfo(bytes32 borrowingKey) external view returns (struct ILiquidityManager.LoanInfo[] loans)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| borrowingKey | bytes32 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| loans | ILiquidityManager.LoanInfo[] | undefined |

### getPlatformFeesInfo

```solidity
function getPlatformFeesInfo(address[] tokens) external view returns (uint256[] fees)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| tokens | address[] | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| fees | uint256[] | undefined |

### harvest

```solidity
function harvest(bytes32 borrowingKey) external nonpayable returns (uint256 harvestedAmt)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| borrowingKey | bytes32 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| harvestedAmt | uint256 | undefined |

### increaseCollateralBalance

```solidity
function increaseCollateralBalance(bytes32 borrowingKey, uint256 collateralAmt, uint256 deadline) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| borrowingKey | bytes32 | undefined |
| collateralAmt | uint256 | undefined |
| deadline | uint256 | undefined |

### lightQuoterV3Address

```solidity
function lightQuoterV3Address() external view returns (address)
```






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

### platformFeesBP

```solidity
function platformFeesBP() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

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





#### Parameters

| Name | Type | Description |
|---|---|---|
| swapTarget | address | undefined |
| funcSelector | bytes4 | undefined |
| isAllowed | bool | undefined |

### swapIsWhitelisted

```solidity
function swapIsWhitelisted(address swapTarget, bytes4 selector) external view returns (bool IsWhitelisted)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| swapTarget | address | undefined |
| selector | bytes4 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| IsWhitelisted | bool | undefined |

### underlyingPositionManager

```solidity
function underlyingPositionManager() external view returns (contract INonfungiblePositionManager)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract INonfungiblePositionManager | undefined |

### updateHoldTokenDailyRate

```solidity
function updateHoldTokenDailyRate(address saleToken, address holdToken, uint256 value) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| saleToken | address | undefined |
| holdToken | address | undefined |
| value | uint256 | undefined |

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





#### Parameters

| Name | Type | Description |
|---|---|---|
| _item | enum IOwnerSettings.ITEM | undefined |
| values | uint256[] | undefined |



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



## Errors

### TooLittleReceivedError

```solidity
error TooLittleReceivedError(uint256 minOut, uint256 out)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| minOut | uint256 | undefined |
| out | uint256 | undefined |


