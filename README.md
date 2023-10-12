# wagmi-leverage

## main entry points:

### borrow

Borrow function allows a user to borrow tokens by providing collateral and taking out loans.
The trader opens a long position by borrowing the liquidity of Uniswap V3 and extracting it into a pair of tokens,one of which will be swapped into a desired(holdToken).The tokens will be kept in storage until the position is closed.The margin is calculated on the basis that liquidity must be restored with any price movement.The time the position is held is paid by the trader.

### repay

This function is used to repay a loan.The position is closed either by the trader or by the liquidator if the trader has not paid for holding the position and the moment of liquidation has arrived.The positions borrowed from liquidation providers are restored from the held token and the remainder is sent to the caller.In the event of liquidation, the liquidity provider whose liquidity is present in the trader’s position can use the emergency mode and withdraw their liquidity.In this case, he will receive hold tokens and liquidity will not be restored in the uniswap pool.


## Dev docs
### LiquidityBorrowingManager [![LiquidityBorrowingManager](https://img.shields.io/badge/docs-%F0%9F%93%84-yellow)](./docs/LiquidityBorrowingManager.md)

## Deployed

### Addresses

| Network | ChainId | Contract | Address |
|------| ------- | -----| -----|
| Arbitrum | 42161 | LiquidityBorrowingManager | [0xbC5e0bB66C9C4036f1172f2132ef8b9030Dfe99E](https://arbiscan.io/address/0xbC5e0bB66C9C4036f1172f2132ef8b9030Dfe99E) |
| Arbitrum | 42161 | Vault| [0x7EDcBF19EA78331607Df7bf002a4bdB516e12389](https://arbiscan.io/address/0x7EDcBF19EA78331607Df7bf002a4bdB516e12389) |
