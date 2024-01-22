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

| V3 | Network | ChainId | Contract | Address |
|------|------| ------- | -----| -----|
| Uniswap | Arbitrum | 42161 | LiquidityBorrowingManager | [0x8BF365c75e959d193276715fa65D098C5F2B2d38](https://arbiscan.io/address/0x8BF365c75e959d193276715fa65D098C5F2B2d38) |
| Uniswap | Arbitrum | 42161 | Vault| [0x2Ef1c6a839ebd7F5c8E497b23ecb9B2BC20edFC0](https://arbiscan.io/address/0x2Ef1c6a839ebd7F5c8E497b23ecb9B2BC20edFC0) |
| Sushiswap | Arbitrum | 42161 | LiquidityBorrowingManager | [0xD26Fbd7827f29e3959e34C25E672d0A38227f150](https://arbiscan.io/address/0xD26Fbd7827f29e3959e34C25E672d0A38227f150) |
| Sushiswap | Arbitrum | 42161 | Vault| [0xfe81C3f1bb2f7a652e0c89eee38921e030B3F326](https://arbiscan.io/address/0xfe81C3f1bb2f7a652e0c89eee38921e030B3F326) |
| Wagmi | Kava | 2222 | LiquidityBorrowingManager | [0xB3D421456A08d5f743eC3e184D1a3Ee18fe29494](https://kavascan.com/address/0xB3D421456A08d5f743eC3e184D1a3Ee18fe29494) |
| Wagmi | Kava | 2222 | Vault| [0x0a521944d80c8E48532a705A846514A3cf18726a](https://kavascan.com/address/0x0a521944d80c8E48532a705A846514A3cf18726a) |
| Kinetix | Kava | 2222 | LiquidityBorrowingManager | [0x961439726bA4F4054cC3e027c19390cF4C35D8A3](https://kavascan.com/address/0x961439726bA4F4054cC3e027c19390cF4C35D8A3) |
| Kinetix | Kava | 2222 | Vault| [0xE9542f2af591814090ac01977167A7b1e65925c8](https://kavascan.com/address/0xE9542f2af591814090ac01977167A7b1e65925c8) |

![](1.png "Title")

## Licensing

The primary license for Wagmi Concentrator(Multipool) is the [WAGMI] Source Available License 1.0 (`SAL-1.0`), see [`LICENSE`](./LICENSE.md). However, some files are licensed under `GPL-2.0-or-later` or `MIT`.