# LiquidityBorrowingManager



> LiquidityBorrowingManager



*This contract manages the borrowing liquidity functionality for WAGMI Leverage protocol. It inherits from LiquidityManager, OwnerSettings, DailyRateAndCollateral, and ReentrancyGuard contracts.*

## Methods

### MAX_DAILY_RATE

```solidity
function MAX_DAILY_RATE() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### MAX_NUM_LOANS_PER_POSOTION

```solidity
function MAX_NUM_LOANS_PER_POSOTION() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### MAX_NUM_USER_POSOTION

```solidity
function MAX_NUM_USER_POSOTION() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### MIN_DAILY_RATE

```solidity
function MIN_DAILY_RATE() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

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

### borrowings

```solidity
function borrowings(bytes32) external view returns (address borrower, address saleToken, address holdToken, uint256 feesOwed, uint256 borrowedAmount, uint256 liquidationBonus, uint256 accLoanRatePerShare, uint256 dailyRateCollateral)
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
| accLoanRatePerShare | uint256 | undefined |
| dailyRateCollateral | uint256 | undefined |

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

### increaseDailyRateCollateral

```solidity
function increaseDailyRateCollateral(address borrower, address saleToken, address holdToken, uint256 collateralAmt) external nonpayable
```

This function is used to increase the daily rate collateral for a specific borrowing.



#### Parameters

| Name | Type | Description |
|---|---|---|
| borrower | address | The address of the borrower. |
| saleToken | address | The address of the token being sold in the borrowing. |
| holdToken | address | The address of the token being held as collateral. |
| collateralAmt | uint256 | The amount of collateral to be added. |

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

### platformsFeesInfo

```solidity
function platformsFeesInfo(address) external view returns (uint256)
```

token =&gt; Amt



#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

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
function repay(bytes32 borrowingKey, uint24 swapPoolFee, uint256 slippageBP1000, uint256 deadline) external nonpayable
```

Repays a borrowing



#### Parameters

| Name | Type | Description |
|---|---|---|
| borrowingKey | bytes32 | The key of the borrowing to be repaid |
| swapPoolFee | uint24 | The fee of swapping pool |
| slippageBP1000 | uint256 | The allowed slippage percentage for the swap, in basis points |
| deadline | uint256 | The deadline by which the transaction must be executed |

### specificTokenLiquidationBonus

```solidity
function specificTokenLiquidationBonus(address) external view returns (uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### tokenPairs

```solidity
function tokenPairs(bytes32, uint256) external view returns (uint32 latestUpTimestamp, uint256 accLoanRatePerShare, uint256 currentDailyRate, uint256 totalBorrowed)
```

pairKey =&gt; TokenInfo[]



#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | bytes32 | undefined |
| _1 | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| latestUpTimestamp | uint32 | undefined |
| accLoanRatePerShare | uint256 | undefined |
| currentDailyRate | uint256 | undefined |
| totalBorrowed | uint256 | undefined |

### transferOwnership

```solidity
function transferOwnership(address newOwner) external nonpayable
```



*Transfers ownership of the contract to a new account (`newOwner`). Can only be called by the current owner.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| newOwner | address | undefined |

### underlyingPosBorrowingKeys

```solidity
function underlyingPosBorrowingKeys(uint256, uint256) external view returns (bytes32)
```

tokenId =&gt; BorrowingKeys[]



#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |
| _1 | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bytes32 | undefined |

### underlyingPositionManager

```solidity
function underlyingPositionManager() external view returns (contract INonfungiblePositionManager)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract INonfungiblePositionManager | undefined |

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

This function is used to update the daily rate for holding a borrow position.

*Only the daily rate operator can call this function.The value must be within the range of MIN_DAILY_RATE and MAX_DAILY_RATE.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| saleToken | address | The address of the sale token. |
| holdToken | address | The address of the hold token. |
| value | uint256 | The new value of the daily rate for the hold token. |

### updateSettings

```solidity
function updateSettings(enum OwnerSettings.ITEM _item, uint256[] values) external nonpayable
```

Updates the settings for a given item.

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



## Events

### Borrow

```solidity
event Borrow(address borrower, bytes32 borrowingKey, uint256 borrowedAmount)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| borrower  | address | undefined |
| borrowingKey  | bytes32 | undefined |
| borrowedAmount  | uint256 | undefined |

### CollectProtocol

```solidity
event CollectProtocol(address recipient, address[] tokens, uint256[] amounts)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| recipient  | address | undefined |
| tokens  | address[] | undefined |
| amounts  | uint256[] | undefined |

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





#### Parameters

| Name | Type | Description |
|---|---|---|
| borrower  | address | undefined |
| liquidator  | address | undefined |
| borrowingKey  | bytes32 | undefined |



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
error InvalidRestoredLiquidity(uint256 tokenId, uint128 restoredLiquidity, uint128 borrowedLiquidity, uint256 amount0, uint256 amount1)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| tokenId | uint256 | undefined |
| restoredLiquidity | uint128 | undefined |
| borrowedLiquidity | uint128 | undefined |
| amount0 | uint256 | undefined |
| amount1 | uint256 | undefined |

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


