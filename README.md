# wagmi-leverage

## Installation
```bash
git clone --recursive https://github.com/RealWagmi/wagmi-leverage.git
npm install
mv .env_example .env
npm run compile
npm run test
```


Wagmi Leverage is a landing protocol without liquidation or price oracles. The trader pays for the time to hold the position and only he can decide when to close it.

### borrow

The "borrow" function allows a user to borrow tokens by providing collateral and taking out loans.
The trader opens a long position by borrowing liquidity from Uniswap V3 and converting it into a pair of tokens. One of these tokens will be swapped into the desired "holdToken". The tokens will be stored until the position is closed. The margin is calculated based on the requirement to restore liquidity with any price movement. The trader pays for the time the position is held.

### repay

The "repay" function is used to repay a loan. The position is closed either by the trader or by the liquidator if the trader has not paid for holding the position and the liquidation time has arrived. The borrowed positions from liquidation providers are restored using the held token, and the remaining tokens are sent to the caller. In the event of liquidation, the liquidity provider whose liquidity is present in the trader's position can use the emergency mode to withdraw their liquidity. In this case, they will receive hold tokens, and liquidity will not be restored in the Uniswap pool.


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

### V2.0 beta

| indx | Protocol | Network | supported |
|------| ------- | -----| -----|
| 1 | uniswap | KAVA | ✅ |
| 1 | uniswap | ARBITRUM | ✅ |
| 2 | aave | KAVA | soon |
| 2 | aave | ARBITRUM | soon |

##

| Network | V3 | dexIndex |
|------| ------- | -----|
| KAVA | wagmi | 0 |
| KAVA | kinetix | 1 |
| ARBITRUM | uniswap | 0 |
| ARBITRUM | sushi | 1 |

##

| Network | ChainId | Contract | Address |
|------| ------- | -----| -----|
| KAVA | 2222 | LightQuoterV3 | [0xCa4526D9d02A7Bb005d850c2176E8aE30B970149](https://kavascan.com/address/0xCa4526D9d02A7Bb005d850c2176E8aE30B970149) |
| KAVA | 2222 | FlashLoanAggregator | [0x57b647530B718103B05751278C4835B068FDC491](https://kavascan.com/address/0x57b647530B718103B05751278C4835B068FDC491) |
| ARBITRUM | 42161 | LightQuoterV3 | [0xED5162725277a9f836Af4e56D83e14085692f921](https://arbiscan.io/address/0xED5162725277a9f836Af4e56D83e14085692f921) |
| ARBITRUM | 42161 | FlashLoanAggregator | [0x0BB7f1b8aE4C2C80Ef58c56cab2D07A76fD5C547](https://arbiscan.io/address/0x0BB7f1b8aE4C2C80Ef58c56cab2D07A76fD5C547) |
##

| V3 | Network | ChainId | Contract | Address |
|------|------| ------- | -----| -----|
| Wagmi | KAVA | 2222 | LiquidityBorrowingManager | [0x180cBA6501ECc1E64D66Cf9658ad8BBF5B821deF](https://kavascan.com/address/0x180cBA6501ECc1E64D66Cf9658ad8BBF5B821deF) |
| Wagmi | KAVA | 2222 | Vault| [0x5cBa9B2c6a7004C120481ACa72ab4CA75E516AED](https://kavascan.com/address/0x5cBa9B2c6a7004C120481ACa72ab4CA75E516AED) |
| Wagmi | KAVA | 2222 | PositionEffectivityChart| [0x89792C7b478cf25220EE7fCF0F445Ea134A992f4](https://kavascan.com/address/0x89792C7b478cf25220EE7fCF0F445Ea134A992f4) |
| Kinetix | KAVA | 2222 | LiquidityBorrowingManager | [0x5037de5B646AF604f964Dd86c0D9719459122454](https://kavascan.com/address/0x5037de5B646AF604f964Dd86c0D9719459122454) |
| Kinetix | KAVA | 2222 | Vault| [0x7D05964F271Cb30a2DD18DcE7363e1155a5bA1Ff](https://kavascan.com/address/0x7D05964F271Cb30a2DD18DcE7363e1155a5bA1Ff) |
| Kinetix | KAVA | 2222 | PositionEffectivityChart| [0x8c5863C690e99e4625789f7ebb7374b5CD091895](https://kavascan.com/address/0x8c5863C690e99e4625789f7ebb7374b5CD091895) |
| Uniswap | ARBITRUM | 42161 | LiquidityBorrowingManager | [0x7C261c6c2F43ec86fbc8DA48505fDF12D66193c9](https://arbiscan.io/address/0x7C261c6c2F43ec86fbc8DA48505fDF12D66193c9) |
| Uniswap | ARBITRUM | 42161 | Vault| [0x72f25285541F8D553d03fd65A8122a80Fc5d722A](https://arbiscan.io/address/0x72f25285541F8D553d03fd65A8122a80Fc5d722A) |
| Uniswap | ARBITRUM | 42161 | PositionEffectivityChart| [0x6Aa98EAD889D8B78C8E369D5139Abd4A720eBE89](https://arbiscan.io/address/0x6Aa98EAD889D8B78C8E369D5139Abd4A720eBE89) |


##

![](1.png "Title")

## Licensing

The primary license for Wagmi Concentrator(Multipool) is the [WAGMI] Source Available License 1.0 (`SAL-1.0`), see [`LICENSE`](./LICENSE.md). However, some files are licensed under `GPL-2.0-or-later` or `MIT`.