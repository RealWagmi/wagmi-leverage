# wagmi-leverage

## Installation
```bash
git clone --recursive https://github.com/RealWagmi/wagmi-leverage.git
npm install
mv .env_example .env
npm run compile
npm run test:all
```


Wagmi Leverage is a leverage product, built on concentrated liquidity without a price-based liquidation or price oracles. This system caters to liquidity providers and traders(borrowers). The trader pays for the time to hold the position as long as he wants as long as interest is paid.

### Liquidity Providers (LPs): 
Wagmi enhances yields for V3 liquidity providers by offsetting impermanent loss. LPs can earn yield even when their liquidity position is out of range. When not utilized for trading, their liquidity position is lent to traders/borrowers, earning them higher yields through premiums and trading fees​​.

### Traders: 
Traders on Wagmi can margin long or short any pair without the risk of forced price-based liquidations. Even if their position is underwater, they are only required to pay premiums to LPs to maintain their position. This model gives traders access to high leverage on every asset and eliminates the concern of forced liquidations​​.



## Dev docs
### LiquidityBorrowingManager [![LiquidityBorrowingManager](https://img.shields.io/badge/docs-%F0%9F%93%84-yellow)](./docs/LiquidityBorrowingManager.md)

## Deployed

### V1.5

| Network | ChainId | Contract | Address |
|------| ------- | -----| -----|
| METIS | 1088 | LightQuoterV3 | [0x5A9fd95e3f865d416bb77b49d1Cca8109FcAbfE5](https://explorer.metis.io/address/0x5A9fd95e3f865d416bb77b49d1Cca8109FcAbfE5) |

##



| V3 | Network | ChainId | Contract | Address |
|------|------| ------- | -----| -----|
| Wagmi | METIS | 1088 | LiquidityBorrowingManager | [0x20fa274D00fF4917A13cD464FDbB200475B6EaBd](https://explorer.metis.io/address/0x20fa274D00fF4917A13cD464FDbB200475B6EaBd) |
| Wagmi | METIS | 1088 | Vault| [0x5e0e38F49c89D2535D12459a3Cab40dB6D2f7fC9](https://explorer.metis.io/address/0x5e0e38F49c89D2535D12459a3Cab40dB6D2f7fC9) |
| Wagmi | METIS | 1088 | PositionEffectivityChart| [0xbbF979671b95fB27Ab19d817Fc41E6F51D4a9Bf9](https://explorer.metis.io/address/0xbbF979671b95fB27Ab19d817Fc41E6F51D4a9Bf9) |

##

### V2.0

| indx | Protocol | KAVA | ARBITRUM | METIS | BASE |
|------| ------- | -----| -----| -----| -----|
| 1 | uniswap | ✅ | ✅ | ✅ | ✅ |
| 2 | aave | ❌ | ✅ | ❌ | ✅ |

##

| Network | V3 | dexIndex |
|------| ------- | -----|
| KAVA | wagmi | 0 |
| KAVA | kinetix | 1 |
| ARBITRUM | uniswap | 0 |
| ARBITRUM | sushi | 1 |
| ARBITRUM | pancake | 2 |
| METIS | wagmi | 0 |
| METIS | hercules | 1 |
| BASE | uniswap | 0 |
| BASE | sushi | 1 |
| BASE | pancake | 2 |

##

| Network | ChainId | Contract | Address |
|------| ------- | -----| -----|
| KAVA | 2222 | LightQuoterV3 | [0x1C9B724cBd7683c80226cE35a39F9127950ABb95](https://kavascan.com/address/0x1C9B724cBd7683c80226cE35a39F9127950ABb95) |
| KAVA | 2222 | FlashLoanAggregator | [0x923e559a12d856f3217b715fE98a7a07CabD6Ed7](https://kavascan.com/address/0x923e559a12d856f3217b715fE98a7a07CabD6Ed7) |
| ARBITRUM | 42161 | LightQuoterV3 | [0x4948f07aCEF9958eb03f1F46f5A949594f2dA2D9](https://arbiscan.io/address/0x4948f07aCEF9958eb03f1F46f5A949594f2dA2D9) |
| ARBITRUM | 42161 | FlashLoanAggregator | [0xAB4bc49175003EBdc7BD6bFae4afC700b185FdA9](https://arbiscan.io/address/0xAB4bc49175003EBdc7BD6bFae4afC700b185FdA9) |
| METIS | 1088 | LightQuoterV3 | [0x3963793a9FB287Ac83aE3eAe849Ef35c98E4CE98](https://explorer.metis.io/address/0x3963793a9FB287Ac83aE3eAe849Ef35c98E4CE98) |
| METIS | 1088 | FlashLoanAggregator | [0x056df39aCe357C1ABf67fb090e36C9ec126c8828](https://explorer.metis.io/address/0x056df39aCe357C1ABf67fb090e36C9ec126c8828) |
| BASE | 8453 | LightQuoterV3 | [0xC49c177736107fD8351ed6564136B9ADbE5B1eC3](https://basescan.org/address/0xC49c177736107fD8351ed6564136B9ADbE5B1eC3) |
| BASE | 8453 | FlashLoanAggregator | [0x7dD9B456Ef365D1e33b4733f9E796a1F5bB79c40](https://basescan.org/address/0x7dD9B456Ef365D1e33b4733f9E796a1F5bB79c40) |

##

| V3 | Network | ChainId | Contract | Address |
|------|------| ------- | -----| -----|
| wagmi | KAVA | 2222 | LiquidityBorrowingManager | [0x496775412549d27A1eC4dDAde02c5c50C50dd8eE](https://kavascan.com/address/0x496775412549d27A1eC4dDAde02c5c50C50dd8eE) |
| wagmi | KAVA | 2222 | Vault| [0xcdef84CB4d361f4B4914D4751FcDca2CE11Ee55B](https://kavascan.com/address/0xcdef84CB4d361f4B4914D4751FcDca2CE11Ee55B) |
| wagmi | KAVA | 2222 | PositionEffectivityChart| [0x755C71DEF546e541fffA7B78f6888D7a41d6d18F](https://kavascan.com/address/0x755C71DEF546e541fffA7B78f6888D7a41d6d18F) |
| wagmi | METIS | 1088 | LiquidityBorrowingManager | [0x25a31a36Ff56Bc5570fd09Ac2da062115DAeb54e](https://explorer.metis.io/address/0x25a31a36Ff56Bc5570fd09Ac2da062115DAeb54e) |
| wagmi | METIS| 1088 | Vault| [0x9cB36c835f189c40bD9cd1cf298717B7bb9e3630](https://explorer.metis.io/address/0x9cB36c835f189c40bD9cd1cf298717B7bb9e3630) |
| wagmi | METIS | 1088 | PositionEffectivityChart| [0x2c80042504A5C0710e38B0dBD85ee5eB6f1A11CD](https://explorer.metis.io/address/0x2c80042504A5C0710e38B0dBD85ee5eB6f1A11CD) |
| kinetix | KAVA | 2222 | LiquidityBorrowingManager | [0xf58a7048b36b2A67dDda4f0E32E76B1081F3AaF0](https://kavascan.com/address/0xf58a7048b36b2A67dDda4f0E32E76B1081F3AaF0) |
| kinetix | KAVA | 2222 | Vault| [0x5A3F804c853b388f0619Ebf085F94927E7f03470](https://kavascan.com/address/0x5A3F804c853b388f0619Ebf085F94927E7f03470) |
| kinetix | KAVA | 2222 | PositionEffectivityChart| [0xc01328369EBfE292991bbbAeD986D9Db2B4AEA91](https://kavascan.com/address/0xc01328369EBfE292991bbbAeD986D9Db2B4AEA91) |
| uniswap | ARBITRUM | 42161 | LiquidityBorrowingManager | [0xda57F8C3466d42D58B505ED9121F348210Ac78A4](https://arbiscan.io/address/0xda57F8C3466d42D58B505ED9121F348210Ac78A4) |
| uniswap | ARBITRUM | 42161 | Vault| [0xc69F42f9aE0f6B6Ae5cF5766Ab47b57f7966EcDA](https://arbiscan.io/address/0xc69F42f9aE0f6B6Ae5cF5766Ab47b57f7966EcDA) |
| uniswap | ARBITRUM | 42161 | PositionEffectivityChart| [0x195b6dC59aDaB228347f4509b7ABd1f530ee88Bb](https://arbiscan.io/address/0x195b6dC59aDaB228347f4509b7ABd1f530ee88Bb) |
| sushi | ARBITRUM | 42161 | LiquidityBorrowingManager | [0xF0F3FC7Da32D49BaB7730142817B2B2111427dc1](https://arbiscan.io/address/0xF0F3FC7Da32D49BaB7730142817B2B2111427dc1) |
| sushi | ARBITRUM | 42161 | Vault| [0x5429f799c11aEF099863a941802073510e83BB1A](https://arbiscan.io/address/0x5429f799c11aEF099863a941802073510e83BB1A) |
| sushi | ARBITRUM | 42161 | PositionEffectivityChart| [0x2f08131C0a668a1224FB21DF177B83B5AF3c6968](https://arbiscan.io/address/0x2f08131C0a668a1224FB21DF177B83B5AF3c6968) |
| uniswap | BASE | 8453 | LiquidityBorrowingManager | [0x7228b8110d9A85BD6740bE03677Eb6deDe0546a8](https://basescan.org/address/0x7228b8110d9A85BD6740bE03677Eb6deDe0546a8) |
| uniswap | BASE | 8453 | Vault| [0x39f3e1b6348ec7d413F3E8e6Df78fE4E01D3F89F](https://basescan.org/address/0x39f3e1b6348ec7d413F3E8e6Df78fE4E01D3F89F) |
| uniswap | BASE | 8453 | PositionEffectivityChart| [0x141cB6458c8090B23539083C6545070D2ce4EF87](https://basescan.org/address/0x141cB6458c8090B23539083C6545070D2ce4EF87) |
| sushi | BASE | 8453 | LiquidityBorrowingManager | [0xe1f435DfcD6969Ae22E96AAB56D5bA1BC837B1d5](https://basescan.org/address/0xe1f435DfcD6969Ae22E96AAB56D5bA1BC837B1d5) |
| sushi | BASE | 8453 | Vault| [0x9d040Aa0d426a98AafF5D38b50E1EAd22B81A5DA](https://basescan.org/address/0x9d040Aa0d426a98AafF5D38b50E1EAd22B81A5DA) |
| sushi | BASE | 8453 | PositionEffectivityChart| [0x69DAD44b15d484bDBb5a3F217605Ff037c26b705](https://basescan.org/address/0x69DAD44b15d484bDBb5a3F217605Ff037c26b705) |

##

![](1.png "Title")

## Licensing

The primary license for Wagmi Concentrator(Multipool) is the [WAGMI] Source Available License 1.0 (`SAL-1.0`), see [`LICENSE`](./LICENSE.md). However, some files are licensed under `GPL-2.0-or-later` or `MIT`.