# wagmi-leverage

## Installation
```bash
git clone --recursive https://github.com/RealWagmi/wagmi-leverage.git
npm install
mv .env_example .env
npm run test
```

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
| Kava | 2222 | LightQuoterV3 | [0x7E23BEcf8d50E49D366c7A46f3F188187c098463](https://kavascan.com/address/0x7E23BEcf8d50E49D366c7A46f3F188187c098463) |
| METIS | 1088 | LightQuoterV3 | [0xF3a53859420a597f0aa20F3A227d0dCfE0825fdd](https://explorer.metis.io/address/0xF3a53859420a597f0aa20F3A227d0dCfE0825fdd) |

##

| V3 | Network | ChainId | Contract | Address |
|------|------| ------- | -----| -----|
| Wagmi | METIS | 1088 | LiquidityBorrowingManager | [0x215C0E817a3C11F622E774560f0638b0e94aeC27](https://explorer.metis.io/address/0x215C0E817a3C11F622E774560f0638b0e94aeC27) |
| Wagmi | METIS | 1088 | Vault| [0xe1c3d7925c310B6d5aCDe2Dd291cE3665C19fDcB](https://explorer.metis.io/address/0xe1c3d7925c310B6d5aCDe2Dd291cE3665C19fDcB) |
| Wagmi | METIS | 1088 | PositionEffectivityChart| [0x896C78157b96C5566D0Fe8FcCfB3C1D9e229a7cA](https://explorer.metis.io/address/0x896C78157b96C5566D0Fe8FcCfB3C1D9e229a7cA) |

##

![](1.png "Title")

## Licensing

The primary license for Wagmi Concentrator(Multipool) is the [WAGMI] Source Available License 1.0 (`SAL-1.0`), see [`LICENSE`](./LICENSE.md). However, some files are licensed under `GPL-2.0-or-later` or `MIT`.