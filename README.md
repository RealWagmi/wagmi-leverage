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

| indx | Protocol | KAVA | ARBITRUM | METIS |
|------| ------- | -----| -----| -----|
| 1 | uniswap | ✅ | ✅ | ✅ |
| 2 | aave | ❌ | ✅ | ❌ |

##

| Network | V3 | dexIndex |
|------| ------- | -----|
| KAVA | wagmi | 0 |
| KAVA | kinetix | 1 |
| ARBITRUM | uniswap | 0 |
| ARBITRUM | sushi | 1 |
| ARBITRUM | pancake | 2 |
| METIS | wagmi | 0 |

##

| Network | ChainId | Contract | Address |
|------| ------- | -----| -----|
| KAVA | 2222 | LightQuoterV3 | [0x1C9B724cBd7683c80226cE35a39F9127950ABb95](https://kavascan.com/address/0x1C9B724cBd7683c80226cE35a39F9127950ABb95) |
| KAVA | 2222 | FlashLoanAggregator | [0x923e559a12d856f3217b715fE98a7a07CabD6Ed7](https://kavascan.com/address/0x923e559a12d856f3217b715fE98a7a07CabD6Ed7) |
| ARBITRUM | 42161 | LightQuoterV3 | [0x4948f07aCEF9958eb03f1F46f5A949594f2dA2D9](https://arbiscan.io/address/0x4948f07aCEF9958eb03f1F46f5A949594f2dA2D9) |
| ARBITRUM | 42161 | FlashLoanAggregator | [0xAB4bc49175003EBdc7BD6bFae4afC700b185FdA9](https://arbiscan.io/address/0xAB4bc49175003EBdc7BD6bFae4afC700b185FdA9) |
| METIS | 1088 | LightQuoterV3 | [0x3963793a9FB287Ac83aE3eAe849Ef35c98E4CE98](https://explorer.metis.io/address/0x3963793a9FB287Ac83aE3eAe849Ef35c98E4CE98) |
| METIS | 1088 | FlashLoanAggregator | [0xCC096c9eFafbf8062F3Bf9894D08E9E912850E1d](https://explorer.metis.io/address/0xCC096c9eFafbf8062F3Bf9894D08E9E912850E1d) |

##

| V3 | Network | ChainId | Contract | Address |
|------|------| ------- | -----| -----|
| wagmi | KAVA | 2222 | LiquidityBorrowingManager | [0x509C3dc2f8e0ED449CEc8c766A9F5A94E1768d80](https://kavascan.com/address/0x509C3dc2f8e0ED449CEc8c766A9F5A94E1768d80) |
| wagmi | KAVA | 2222 | Vault| [0xAC253339AE3C75E2dbAB375Da8Bac9c19B6614f9](https://kavascan.com/address/0xAC253339AE3C75E2dbAB375Da8Bac9c19B6614f9) |
| wagmi | KAVA | 2222 | PositionEffectivityChart| [0x8cf6FFDb1E544348988c151296911beF15A11E2a](https://kavascan.com/address/0x8cf6FFDb1E544348988c151296911beF15A11E2a) |
| wagmi | METIS | 1088 | LiquidityBorrowingManager | [0x9ac33eeccF1c88c4aC13d800D6e5aa4C75C6125c](https://explorer.metis.io/address/0x9ac33eeccF1c88c4aC13d800D6e5aa4C75C6125c) |
| wagmi | METIS| 1088 | Vault| [0xa762032CdB17c262e23639A769EDc7aAE5db3002](https://explorer.metis.io/address/0xa762032CdB17c262e23639A769EDc7aAE5db3002) |
| wagmi | METIS | 1088 | PositionEffectivityChart| [0x48Cc6C8c69662fa3FCd579936041c0C3Ec8DCEE7](https://explorer.metis.io/address/0x48Cc6C8c69662fa3FCd579936041c0C3Ec8DCEE7) |
| kinetix | KAVA | 2222 | LiquidityBorrowingManager | [0xEb4A370Ff9F67080828e21B7395dFA91E38472F4](https://kavascan.com/address/0xEb4A370Ff9F67080828e21B7395dFA91E38472F4) |
| kinetix | KAVA | 2222 | Vault| [0x18FB4c6c62301145384e893Bd71e32a78c4A81D3](https://kavascan.com/address/0x18FB4c6c62301145384e893Bd71e32a78c4A81D3) |
| kinetix | KAVA | 2222 | PositionEffectivityChart| [0x3753D5B59ce749c277e8698fcB2875535781F843](https://kavascan.com/address/0x3753D5B59ce749c277e8698fcB2875535781F843) |
| uniswap | ARBITRUM | 42161 | LiquidityBorrowingManager | [0xda57F8C3466d42D58B505ED9121F348210Ac78A4](https://arbiscan.io/address/0xda57F8C3466d42D58B505ED9121F348210Ac78A4) |
| uniswap | ARBITRUM | 42161 | Vault| [0xc69F42f9aE0f6B6Ae5cF5766Ab47b57f7966EcDA](https://arbiscan.io/address/0xc69F42f9aE0f6B6Ae5cF5766Ab47b57f7966EcDA) |
| uniswap | ARBITRUM | 42161 | PositionEffectivityChart| [0x195b6dC59aDaB228347f4509b7ABd1f530ee88Bb](https://arbiscan.io/address/0x195b6dC59aDaB228347f4509b7ABd1f530ee88Bb) |
| sushi | ARBITRUM | 42161 | LiquidityBorrowingManager | [0xF0F3FC7Da32D49BaB7730142817B2B2111427dc1](https://arbiscan.io/address/0xF0F3FC7Da32D49BaB7730142817B2B2111427dc1) |
| sushi | ARBITRUM | 42161 | Vault| [0x5429f799c11aEF099863a941802073510e83BB1A](https://arbiscan.io/address/0x5429f799c11aEF099863a941802073510e83BB1A) |
| sushi | ARBITRUM | 42161 | PositionEffectivityChart| [0x2f08131C0a668a1224FB21DF177B83B5AF3c6968](https://arbiscan.io/address/0x2f08131C0a668a1224FB21DF177B83B5AF3c6968) |


##

![](1.png "Title")

## Licensing

The primary license for Wagmi Concentrator(Multipool) is the [WAGMI] Source Available License 1.0 (`SAL-1.0`), see [`LICENSE`](./LICENSE.md). However, some files are licensed under `GPL-2.0-or-later` or `MIT`.