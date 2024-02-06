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
| Arbitrum | 42161 | LightQuoterV3 | [0x5Aad6a48929D31Dd66aFA5Ab2A783209c7B35509](https://arbiscan.io/address/0x5Aad6a48929D31Dd66aFA5Ab2A783209c7B35509) |
| Kava | 2222 | LightQuoterV3 | [0x900BE45982cB0b2E573ee109e67e1a0D4FC47Fff](https://kavascan.com/address/0x900BE45982cB0b2E573ee109e67e1a0D4FC47Fff) |
| METIS | 1088 | LightQuoterV3 | [0xdd9c5CA0270809b091bf477a7e28890EA1cbd1cF](https://explorer.metis.io/address/0xdd9c5CA0270809b091bf477a7e28890EA1cbd1cF) |

##

| V3 | Network | ChainId | Contract | Address |
|------|------| ------- | -----| -----|
| Uniswap | Arbitrum | 42161 | LiquidityBorrowingManager | [0x793288e6B1bd67fFC3d31992c54e0a3B2bDd655c](https://arbiscan.io/address/0x793288e6B1bd67fFC3d31992c54e0a3B2bDd655c) |
| Uniswap | Arbitrum | 42161 | Vault| [0xaEb20c4f9D9df915697B6aC6518458Fa2FA8AC80](https://arbiscan.io/address/0xaEb20c4f9D9df915697B6aC6518458Fa2FA8AC80) |
| Sushiswap | Arbitrum | 42161 | LiquidityBorrowingManager | [0x6374e71E15C6c7706237386584EC8c55c97e7bDa](https://arbiscan.io/address/0x6374e71E15C6c7706237386584EC8c55c97e7bDa) |
| Sushiswap | Arbitrum | 42161 | Vault| [0x86397aA2AFe9BFa1d76bc8963d248ef9B40837aC](https://arbiscan.io/address/0x86397aA2AFe9BFa1d76bc8963d248ef9B40837aC) |
| Wagmi | Kava | 2222 | LiquidityBorrowingManager | [0xCc99476805F82e1446541FCb1010269EbC092ae2](https://kavascan.com/address/0xCc99476805F82e1446541FCb1010269EbC092ae2) |
| Wagmi | Kava | 2222 | Vault| [0xCFE7beDD2bfa1C348ec8de1e210be079bc0eD13e](https://kavascan.com/address/0xCFE7beDD2bfa1C348ec8de1e210be079bc0eD13e) |
| Kinetix | Kava | 2222 | LiquidityBorrowingManager | [0x45861d6700eAFdD9C8cAD21348ecC2a90328F3E1](https://kavascan.com/address/0x45861d6700eAFdD9C8cAD21348ecC2a90328F3E1) |
| Kinetix | Kava | 2222 | Vault| [0xEF28cC9dd2e68f3496Fa432876CA055ffdFCc5c1](https://kavascan.com/address/0xEF28cC9dd2e68f3496Fa432876CA055ffdFCc5c1) |
| Wagmi | METIS | 1088 | LiquidityBorrowingManager | [0x3C422982E76261a3eC73363CAcf5C3731e318104](https://explorer.metis.io/address/0x3C422982E76261a3eC73363CAcf5C3731e318104) |
| Wagmi | METIS | 1088 | Vault| [0xfa0769525516D247ee040188e029798A259f0e0E](https://explorer.metis.io/address/0xfa0769525516D247ee040188e029798A259f0e0E) |

##

![](1.png "Title")

## Licensing

The primary license for Wagmi Concentrator(Multipool) is the [WAGMI] Source Available License 1.0 (`SAL-1.0`), see [`LICENSE`](./LICENSE.md). However, some files are licensed under `GPL-2.0-or-later` or `MIT`.