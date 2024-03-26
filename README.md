# wagmi-leverage

## Installation
```bash
git clone --recursive https://github.com/RealWagmi/wagmi-leverage.git
npm install
mv .env_example .env
npm run compile
npm run test
```


Wagmi Leverage is a leverage product, built on concentrated liquidity without a price-based liquidation or price oracles. This system caters to liquidity providers and traders(borrowers). The trader pays for the time to hold the position as long as he wants as long as interest is paid.

### Liquidity Providers (LPs): 
Wagmi enhances yields for V3 liquidity providers by offsetting impermanent loss. LPs can earn yield even when their liquidity position is out of range. When not utilized for trading, their liquidity position is lent to traders/borrowers, earning them higher yields through premiums and trading fees​​.

### Traders: 
Traders on Wagmi can margin long or short any pair without the risk of forced price-based liquidations. Even if their position is underwater, they are only required to pay premiums to LPs to maintain their position. This model gives traders access to high leverage on every asset and eliminates the concern of forced liquidations​​.



## Dev docs
### LiquidityBorrowingManager [![LiquidityBorrowingManager](https://img.shields.io/badge/docs-%F0%9F%93%84-yellow)](./docs/LiquidityBorrowingManager.md)

## Deployed

### V2.0

| indx | Protocol |BSC | ARBITRUM |
|------| ------- | -----| -----|
| 1 | uniswap | ✅ | ✅ |
| 2 | aave | ✅ | ✅ |

##

| Network | V3 | dexIndex |
|------| ------- | -----|
| BSC | pancake | 0 |
| BSC | uniswap | 1 |
| BSC | sushi | 2 |
| ARBITRUM | uniswap | 0 |
| ARBITRUM | sushi | 1 |
| ARBITRUM | pancake | 2 |

##

| Network | ChainId | Contract | Address |
|------| ------- | -----| -----|
| BSC | 56 | LightQuoterV3 | [0xC49c177736107fD8351ed6564136B9ADbE5B1eC3](https://bscscan.com/address/0xC49c177736107fD8351ed6564136B9ADbE5B1eC3) |
| BSC | 56 | FlashLoanAggregator | [0xe1f435DfcD6969Ae22E96AAB56D5bA1BC837B1d5](https://bscscan.com/address/0xe1f435DfcD6969Ae22E96AAB56D5bA1BC837B1d5) |
| ARBITRUM | 42161 | LightQuoterV3 | [0xCaDD693F005A5af8bF7Afa2BF45DFA8d61053DB6](https://arbiscan.io/address/0xCaDD693F005A5af8bF7Afa2BF45DFA8d61053DB6) |
| ARBITRUM | 42161 | FlashLoanAggregator | [0x923e559a12d856f3217b715fE98a7a07CabD6Ed7](https://arbiscan.io/address/0x923e559a12d856f3217b715fE98a7a07CabD6Ed7) |
##

| Network | ChainId | Contract | Address |
|------| ------- | -----| -----|
| BSC | 56 | LiquidityBorrowingManager | [0x7228b8110d9A85BD6740bE03677Eb6deDe0546a8](https://bscscan.com/address/0x7228b8110d9A85BD6740bE03677Eb6deDe0546a8) |
| BSC | 56 | Vault| [0x7D9A602ff2582C1111C47134914415Ba4F1323A5](https://bscscan.com/address/0x7D9A602ff2582C1111C47134914415Ba4F1323A5) |
| BSC | 56 | PositionEffectivityChart| [0x141cB6458c8090B23539083C6545070D2ce4EF87](https://bscscan.com/address/0x141cB6458c8090B23539083C6545070D2ce4EF87) |
| ARBITRUM | 42161 | LiquidityBorrowingManager | [0x4a7d1Bd77557461aBa23b74bF41153034524107b](https://arbiscan.io/address/0x4a7d1Bd77557461aBa23b74bF41153034524107b) |
| ARBITRUM | 42161 | Vault| [0xC7e051C6A1dA34E6aE8171DB3de38515388D85f8](https://arbiscan.io/address/0xC7e051C6A1dA34E6aE8171DB3de38515388D85f8) |
| ARBITRUM | 42161 | PositionEffectivityChart| [0x521C2d8Be14060B7617c2E2597eE9b52A995E65F](https://arbiscan.io/address/0x521C2d8Be14060B7617c2E2597eE9b52A995E65F) |

##

![](1.png "Title")

## Licensing

The primary license for Wagmi Concentrator(Multipool) is the [WAGMI] Source Available License 1.0 (`SAL-1.0`), see [`LICENSE`](./LICENSE.md). However, some files are licensed under `GPL-2.0-or-later` or `MIT`.