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
| Arbitrum | 42161 | LightQuoterV3 | [0x89edB9a26Bdf692fC9c89b5A78fF456433Dfc3fc](https://arbiscan.io/address/0x89edB9a26Bdf692fC9c89b5A78fF456433Dfc3fc) |
| Kava | 2222 | LightQuoterV3 | [0x46ccC72dfE0B552329a2D3c3384bb2B96b23CF52](https://kavascan.com/address/0x46ccC72dfE0B552329a2D3c3384bb2B96b23CF52) |
| METIS | 1088 | LightQuoterV3 | [0xaB120F1FD31FB1EC39893B75d80a3822b1Cd8d0c](https://explorer.metis.io/address/0xaB120F1FD31FB1EC39893B75d80a3822b1Cd8d0c) |

##

| V3 | Network | ChainId | Contract | Address |
|------|------| ------- | -----| -----|
| Uniswap | Arbitrum | 42161 | LiquidityBorrowingManager | [0x44f4E18B1D4D8c0517a5163a4a6f33534d50d71e](https://arbiscan.io/address/0x44f4E18B1D4D8c0517a5163a4a6f33534d50d71e) |
| Uniswap | Arbitrum | 42161 | Vault| [0xb2Fc7d6b5420456856FC73c234Aa73fe7D6399A1](https://arbiscan.io/address/0xb2Fc7d6b5420456856FC73c234Aa73fe7D6399A1) |
| Uniswap | Arbitrum | 42161 | PositionEffectivityChart| [0xa3817414Dd31a07cbcc74894d25069f73A87a64b](https://arbiscan.io/address/0xa3817414Dd31a07cbcc74894d25069f73A87a64b) |
| Sushiswap | Arbitrum | 42161 | LiquidityBorrowingManager | [0x663bAAC9D162b23aB324b46707CE3dE353405663](https://arbiscan.io/address/0x663bAAC9D162b23aB324b46707CE3dE353405663) |
| Sushiswap | Arbitrum | 42161 | Vault| [0x6faA75527DE14ded1A90D25F052260Ad175EBeea](https://arbiscan.io/address/0x6faA75527DE14ded1A90D25F052260Ad175EBeea) |
| Sushiswap | Arbitrum | 42161 | PositionEffectivityChart| [0x941FFdE71f0B3dd32c191fA28A1c2310361ece84](https://arbiscan.io/address/0x941FFdE71f0B3dd32c191fA28A1c2310361ece84) |
| Wagmi | Kava | 2222 | LiquidityBorrowingManager | [0xfB0114e6eeC8B2740f5fDc71F62dA1De11a8678D](https://kavascan.com/address/0xfB0114e6eeC8B2740f5fDc71F62dA1De11a8678D) |
| Wagmi | Kava | 2222 | Vault| [0xaf0d0ac1DA67E4FAac5801eEE954511b5DD34414](https://kavascan.com/address/0xaf0d0ac1DA67E4FAac5801eEE954511b5DD34414) |
| Wagmi | Kava | 2222 | PositionEffectivityChart| [0xAa40097C55245AA7a87D248E7e8FF902b3a1D6Ab](https://kavascan.com/address/0xAa40097C55245AA7a87D248E7e8FF902b3a1D6Ab) |
| Kinetix | Kava | 2222 | LiquidityBorrowingManager | [0xdbcbc01b8ba67da94c7C62153a221ffa988feC9D](https://kavascan.com/address/0xdbcbc01b8ba67da94c7C62153a221ffa988feC9D) |
| Kinetix | Kava | 2222 | Vault| [0x2ADBA4119320E2bE5524F16B6aA99fc124bCB962](https://kavascan.com/address/0x2ADBA4119320E2bE5524F16B6aA99fc124bCB962) |
| Kinetix | Kava | 2222 | PositionEffectivityChart| [0x35e79BCe31eF892c24Da7D7C8EFB1d47dB37cA57](https://kavascan.com/address/0x35e79BCe31eF892c24Da7D7C8EFB1d47dB37cA57) |
| Wagmi | METIS | 1088 | LiquidityBorrowingManager | [0x05D73f76689e4844581a9DB03f82960cBf3C4D2b](https://explorer.metis.io/address/0x05D73f76689e4844581a9DB03f82960cBf3C4D2b) |
| Wagmi | METIS | 1088 | Vault| [0x99701EF8002025Fa37Be0e2b2b35124F8339A0e6](https://explorer.metis.io/address/0x99701EF8002025Fa37Be0e2b2b35124F8339A0e6) |
| Wagmi | METIS | 1088 | PositionEffectivityChart| [0x242c5fAaAa8A5fe49a66698fff7bCAb85cF3cF17](https://explorer.metis.io/address/0x242c5fAaAa8A5fe49a66698fff7bCAb85cF3cF17) |

##

![](1.png "Title")

## Licensing

The primary license for Wagmi Concentrator(Multipool) is the [WAGMI] Source Available License 1.0 (`SAL-1.0`), see [`LICENSE`](./LICENSE.md). However, some files are licensed under `GPL-2.0-or-later` or `MIT`.