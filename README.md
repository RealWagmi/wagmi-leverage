# wagmi-leverage

## Installation
```bash
git clone --recursive https://github.com/RealWagmi/wagmi-leverage.git
npm install
mv .env_example .env
npm run compile
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

| Network | ChainId | Contract | Address |
|------| ------- | -----| -----|
| KAVA | 2222 | LightQuoterV3 | [0xCa4526D9d02A7Bb005d850c2176E8aE30B970149](https://kavascan.com/address/0xCa4526D9d02A7Bb005d850c2176E8aE30B970149) |
| KAVA | 2222 | FlashLoanAggregator | [0x57b647530B718103B05751278C4835B068FDC491](https://kavascan.com/address/0x57b647530B718103B05751278C4835B068FDC491) |
##

| V3 | Network | ChainId | Contract | Address |
|------|------| ------- | -----| -----|
| Wagmi | KAVA | 2222 | LiquidityBorrowingManager | [0x180cBA6501ECc1E64D66Cf9658ad8BBF5B821deF](https://kavascan.com/address/0x180cBA6501ECc1E64D66Cf9658ad8BBF5B821deF) |
| Wagmi | KAVA | 2222 | Vault| [0x5cBa9B2c6a7004C120481ACa72ab4CA75E516AED](https://kavascan.com/address/0x5cBa9B2c6a7004C120481ACa72ab4CA75E516AED) |
| Wagmi | KAVA | 2222 | PositionEffectivityChart| [0x89792C7b478cf25220EE7fCF0F445Ea134A992f4](https://kavascan.com/address/0x89792C7b478cf25220EE7fCF0F445Ea134A992f4) |
| Kinetix | KAVA | 2222 | LiquidityBorrowingManager | [0x5037de5B646AF604f964Dd86c0D9719459122454](https://kavascan.com/address/0x5037de5B646AF604f964Dd86c0D9719459122454) |
| Kinetix | KAVA | 2222 | Vault| [0x7D05964F271Cb30a2DD18DcE7363e1155a5bA1Ff](https://kavascan.com/address/0x7D05964F271Cb30a2DD18DcE7363e1155a5bA1Ff) |
| Kinetix | KAVA | 2222 | PositionEffectivityChart| [0x8c5863C690e99e4625789f7ebb7374b5CD091895](https://kavascan.com/address/0x8c5863C690e99e4625789f7ebb7374b5CD091895) |


##

![](1.png "Title")

## Licensing

The primary license for Wagmi Concentrator(Multipool) is the [WAGMI] Source Available License 1.0 (`SAL-1.0`), see [`LICENSE`](./LICENSE.md). However, some files are licensed under `GPL-2.0-or-later` or `MIT`.