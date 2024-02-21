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
| Kava | 2222 | LightQuoterV3 | [0x444Cce074Fc856B11048D992C789c0e316D7f418](https://kavascan.com/address/0x444Cce074Fc856B11048D992C789c0e316D7f418) |
| METIS | 1088 | LightQuoterV3 | [0x16CAd8fbD9878D1fF86A12Eb4A275c7F53B5788e](https://explorer.metis.io/address/0x16CAd8fbD9878D1fF86A12Eb4A275c7F53B5788e) |

##

| V3 | Network | ChainId | Contract | Address |
|------|------| ------- | -----| -----|
| Wagmi | Kava | 2222 | LiquidityBorrowingManager | [0x7bCDC07587f597339735C3D518a054007b73898b](https://kavascan.com/address/0x7bCDC07587f597339735C3D518a054007b73898b) |
| Wagmi | Kava | 2222 | Vault| [0xA5d79225347036a50AF0D270DB554A12291D53E8](https://kavascan.com/address/0xA5d79225347036a50AF0D270DB554A12291D53E8) |
| Wagmi | Kava | 2222 | PositionEffectivityChart| [0xAa40097C55245AA7a87D248E7e8FF902b3a1D6Ab](https://kavascan.com/address/0xAa40097C55245AA7a87D248E7e8FF902b3a1D6Ab) |
| Kinetix | Kava | 2222 | LiquidityBorrowingManager | [0xb4b3628C4Da9b6C6564D4E14277fFa8b3aE50BD6](https://kavascan.com/address/0xb4b3628C4Da9b6C6564D4E14277fFa8b3aE50BD6) |
| Kinetix | Kava | 2222 | Vault| [0x6925640cd93515060F9051D45ECA9CA829316739](https://kavascan.com/address/0x6925640cd93515060F9051D45ECA9CA829316739) |
| Kinetix | Kava | 2222 | PositionEffectivityChart| [0x35e79BCe31eF892c24Da7D7C8EFB1d47dB37cA57](https://kavascan.com/address/0x35e79BCe31eF892c24Da7D7C8EFB1d47dB37cA57) |
| Wagmi | METIS | 1088 | LiquidityBorrowingManager | [0x3De5E32e21a1656d04F3145552735DdB4F4a4A2C](https://explorer.metis.io/address/0x3De5E32e21a1656d04F3145552735DdB4F4a4A2C) |
| Wagmi | METIS | 1088 | Vault| [0x4cf59cC7Cc4C62e780C482d3ff5c6e227e88efc6](https://explorer.metis.io/address/0x4cf59cC7Cc4C62e780C482d3ff5c6e227e88efc6) |
| Wagmi | METIS | 1088 | PositionEffectivityChart| [0x242c5fAaAa8A5fe49a66698fff7bCAb85cF3cF17](https://explorer.metis.io/address/0x242c5fAaAa8A5fe49a66698fff7bCAb85cF3cF17) |

##

![](1.png "Title")

## Licensing

The primary license for Wagmi Concentrator(Multipool) is the [WAGMI] Source Available License 1.0 (`SAL-1.0`), see [`LICENSE`](./LICENSE.md). However, some files are licensed under `GPL-2.0-or-later` or `MIT`.