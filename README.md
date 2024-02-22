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
| Wagmi | Kava | 2222 | LiquidityBorrowingManager | [0x17A2349B3530F3b6082116D2B223edd5862bC3ac](https://kavascan.com/address/0x17A2349B3530F3b6082116D2B223edd5862bC3ac) |
| Wagmi | Kava | 2222 | Vault| [0xacE500f4373Ff7dc4FBa17B6274d02DdAFBA409c](https://kavascan.com/address/0xacE500f4373Ff7dc4FBa17B6274d02DdAFBA409c) |
| Wagmi | Kava | 2222 | PositionEffectivityChart| [0xAa40097C55245AA7a87D248E7e8FF902b3a1D6Ab](https://kavascan.com/address/0xAa40097C55245AA7a87D248E7e8FF902b3a1D6Ab) |
| Kinetix | Kava | 2222 | LiquidityBorrowingManager | [0x43b2fcD81b8dC2A94Cf1eF645EDac763400551a1](https://kavascan.com/address/0x43b2fcD81b8dC2A94Cf1eF645EDac763400551a1) |
| Kinetix | Kava | 2222 | Vault| [0x1AEA6B02B1EcdBD2a6D00E0583855e32756C5786](https://kavascan.com/address/0x1AEA6B02B1EcdBD2a6D00E0583855e32756C5786) |
| Kinetix | Kava | 2222 | PositionEffectivityChart| [0x35e79BCe31eF892c24Da7D7C8EFB1d47dB37cA57](https://kavascan.com/address/0x35e79BCe31eF892c24Da7D7C8EFB1d47dB37cA57) |
| Wagmi | METIS | 1088 | LiquidityBorrowingManager | [0x07614aDBe4188EAf1dD90Eb49cA964307bB2E985](https://explorer.metis.io/address/0x07614aDBe4188EAf1dD90Eb49cA964307bB2E985) |
| Wagmi | METIS | 1088 | Vault| [0x6F1FE2a6598b99b87e10B5cE33c14173eAAd7469](https://explorer.metis.io/address/0x6F1FE2a6598b99b87e10B5cE33c14173eAAd7469) |
| Wagmi | METIS | 1088 | PositionEffectivityChart| [0x242c5fAaAa8A5fe49a66698fff7bCAb85cF3cF17](https://explorer.metis.io/address/0x242c5fAaAa8A5fe49a66698fff7bCAb85cF3cF17) |

##

![](1.png "Title")

## Licensing

The primary license for Wagmi Concentrator(Multipool) is the [WAGMI] Source Available License 1.0 (`SAL-1.0`), see [`LICENSE`](./LICENSE.md). However, some files are licensed under `GPL-2.0-or-later` or `MIT`.