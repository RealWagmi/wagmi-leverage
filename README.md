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
| Arbitrum | 42161 | LightQuoterV3 | [0xb9235A074C68A046308aEbD7414Fb89e674adEae](https://arbiscan.io/address/0xb9235A074C68A046308aEbD7414Fb89e674adEae) |
| Kava | 2222 | LightQuoterV3 | [0xbd352897CF946E205C80520976F6573b7FF3a734](https://kavascan.com/address/0xbd352897CF946E205C80520976F6573b7FF3a734) |

##

| V3 | Network | ChainId | Contract | Address |
|------|------| ------- | -----| -----|
| Uniswap | Arbitrum | 42161 | LiquidityBorrowingManager | [0xaC484BBFE6f2Dfc3DA8AD962194C337424439E38](https://arbiscan.io/address/0xaC484BBFE6f2Dfc3DA8AD962194C337424439E38) |
| Uniswap | Arbitrum | 42161 | Vault| [0x685685054C97698a8EA13b56Ac57cA9f62d8B532](https://arbiscan.io/address/0x685685054C97698a8EA13b56Ac57cA9f62d8B532) |
| Sushiswap | Arbitrum | 42161 | LiquidityBorrowingManager | [0xA46901Db277ed14a136C3146784D4eC9e0C98628](https://arbiscan.io/address/0xA46901Db277ed14a136C3146784D4eC9e0C98628) |
| Sushiswap | Arbitrum | 42161 | Vault| [0xE3e9acdF8400F10da4b6bD8E4c75792739A397C5](https://arbiscan.io/address/0xE3e9acdF8400F10da4b6bD8E4c75792739A397C5) |
| Wagmi | Kava | 2222 | LiquidityBorrowingManager | [0x4aC92419aaB89aF2ac1012e1E0159b26499381a3](https://kavascan.com/address/0x4aC92419aaB89aF2ac1012e1E0159b26499381a3) |
| Wagmi | Kava | 2222 | Vault| [0x0582D344F3570F2196FF32dEf07C96581Fa504b1](https://kavascan.com/address/0x0582D344F3570F2196FF32dEf07C96581Fa504b1) |
| Kinetix | Kava | 2222 | LiquidityBorrowingManager | [0xBA327f7d4734e8ab6BfBd1f2310c02b7dE097A75](https://kavascan.com/address/0xBA327f7d4734e8ab6BfBd1f2310c02b7dE097A75) |
| Kinetix | Kava | 2222 | Vault| [0xf08DBe4dc16B75346C7A18E8939EFBcAb1B4C981](https://kavascan.com/address/0xf08DBe4dc16B75346C7A18E8939EFBcAb1B4C981) |

##

![](1.png "Title")

## Licensing

The primary license for Wagmi Concentrator(Multipool) is the [WAGMI] Source Available License 1.0 (`SAL-1.0`), see [`LICENSE`](./LICENSE.md). However, some files are licensed under `GPL-2.0-or-later` or `MIT`.