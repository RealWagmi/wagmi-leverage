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
| Uniswap | Arbitrum | 42161 | LiquidityBorrowingManager | [0xdfC29937Cc69bB1d45808eCb56EB5B08ed4EeD3d](https://arbiscan.io/address/0xdfC29937Cc69bB1d45808eCb56EB5B08ed4EeD3d) |
| Uniswap | Arbitrum | 42161 | Vault| [0x5115Cd6a44e150bB98fd02aa8E2C32382CB92627](https://arbiscan.io/address/0x5115Cd6a44e150bB98fd02aa8E2C32382CB92627) |
| Sushiswap | Arbitrum | 42161 | LiquidityBorrowingManager | [0xAdB0367855243D025cC1E66FA3296D891D468839](https://arbiscan.io/address/0xAdB0367855243D025cC1E66FA3296D891D468839) |
| Sushiswap | Arbitrum | 42161 | Vault| [0xB6c07217d898ba2aAFB7B407FEb69D62286bb254](https://arbiscan.io/address/0xB6c07217d898ba2aAFB7B407FEb69D62286bb254) |
| Wagmi | Kava | 2222 | LiquidityBorrowingManager | [0x71523Ea3CBEa82dDFdF8435Df79Aa53f21930e32](https://kavascan.com/address/0x71523Ea3CBEa82dDFdF8435Df79Aa53f21930e32) |
| Wagmi | Kava | 2222 | Vault| [0x64c11cdCC29bE731fC28C38621B4E746FE6717a7](https://kavascan.com/address/0x64c11cdCC29bE731fC28C38621B4E746FE6717a7) |
| Kinetix | Kava | 2222 | LiquidityBorrowingManager | [0x7336A896B2e332c9c5B693329E12E715aB3dDaE4](https://kavascan.com/address/0x7336A896B2e332c9c5B693329E12E715aB3dDaE4) |
| Kinetix | Kava | 2222 | Vault| [0x14254b79cB905c31d6b5A9D166c08602bb605A72](https://kavascan.com/address/0x14254b79cB905c31d6b5A9D166c08602bb605A72) |

##

![](1.png "Title")

## Licensing

The primary license for Wagmi Concentrator(Multipool) is the [WAGMI] Source Available License 1.0 (`SAL-1.0`), see [`LICENSE`](./LICENSE.md). However, some files are licensed under `GPL-2.0-or-later` or `MIT`.