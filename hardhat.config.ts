import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "hardhat-storage-layout";
import "hardhat-tracer";
import "@primitivefi/hardhat-dodoc";
import "hardhat-contract-sizer";
// import 'hardhat-exposed';
import { config as dotEnvConfig } from 'dotenv';


dotEnvConfig();

const COMPILER_SETTINGS_OLD = {
  version: '0.6.12',
  settings: {
    //evmVersion: 'istanbul',
    optimizer: {
      enabled: true,
      runs: 200,
    },
    metadata: {
      bytecodeHash: 'none',
    },
  },
};

const COMPILER_SETTINGS = {
  version: '0.8.23',
  settings: {
    viaIR: true,
    evmVersion: "paris",
    optimizer: {
      enabled: true,
      runs: 999,
    },
    metadata: {
      bytecodeHash: 'none',
    },
  },
};

const config: HardhatUserConfig = {
  dodoc: {
    runOnCompile: true,
    debugMode: false,
    freshOutput: true,
    include: ["LiquidityBorrowingManager"]
  },
  defaultNetwork: 'hardhat',
  // exposed: {
  //   include: ["./abstract/*.sol"],
  // },
  gasReporter: {
    currency: 'USD',
    coinmarketcap: process.env.COINMARKETCAP_API_KEY,
    showTimeSpent: true,
    enabled: true,
    excludeContracts: ["ERC20", "ForceSend", "MockERC20", "$ApproveSwapAndPay", "$LiquidityManager"]
  },
  contractSizer: {
    alphaSort: true,
    disambiguatePaths: false,
    runOnCompile: true,
    strict: true,
    only: ["LiquidityBorrowingManager", "LightQuoterV3", "FlashLoanAggregator"],
  },
  paths: {
    sources: './contracts',
    tests: './test',
    artifacts: './artifacts',
    cache: './cache',
  },
  solidity: {
    compilers: [
      {
        version: '0.8.23',
        settings: {
          viaIR: true,
          evmVersion: "paris",
          optimizer: {
            enabled: true,
            runs: 160
          }

        }
      }
    ],
    overrides: {
      'contracts/FlashLoanAggregator.sol': COMPILER_SETTINGS,
      'contracts/LightQuoterV3.sol': COMPILER_SETTINGS,
      'contracts/mock/ForceSend.sol': COMPILER_SETTINGS_OLD,
    },
  },
  networks: {
    hardhat: {
      //hardfork: "istanbul",
      chainId: 1,
      forking: {
        url: "https://rpc.ankr.com/eth",
        blockNumber: 17329500,
      },
      allowBlocksWithSameTimestamp: true,
      allowUnlimitedContractSize: false,
      blockGasLimit: 40000000,
      gas: 40000000,
      gasPrice: 'auto',
      loggingEnabled: false,
      accounts: {
        mnemonic: "test test test test test test test test test test test junk",
        path: "m/44'/60'/0'/0",
        initialIndex: 0,
        count: 5,
        accountsBalance: '1000000000000000000000000000000000',
        passphrase: "",
      },
    },
    ethereum: {
      url: "https://mainnet.infura.io/v3/9aa3d95b3bc440fa88ea12eaa4456161", // public infura endpoint
      chainId: 1,
      gas: 'auto',
      gasMultiplier: 1.2,
      gasPrice: 6000000000,
      accounts: [`${process.env.PRIVATE_KEY}`],
      loggingEnabled: true,
    },
    bsc: {
      url: "https://bsc-dataseed1.binance.org",
      chainId: 56,
      accounts: [`${process.env.PRIVATE_KEY}`],
      gas: 'auto',
      gasMultiplier: 1.2,
      gasPrice: 5000000000,
      loggingEnabled: true,
    },
    avalanche: {
      url: "https://api.avax.network/ext/bc/C/rpc",
      chainId: 43114,
      accounts: [`${process.env.PRIVATE_KEY}`],
    },
    fantom: {
      url: "https://rpcapi.fantom.network",
      chainId: 250,
      accounts: [
        `${process.env.PRIVATE_KEY}`
      ],
      gas: 10000000,
      blockGasLimit: 31000000,
      gasMultiplier: 1.2,
      gasPrice: 65000000000,
      loggingEnabled: true,
    },
    polygon: {
      url: "https://polygon-bor.publicnode.com",
      accounts: [`${process.env.PRIVATE_KEY}`],
      chainId: 137,
      gas: 'auto',
      gasMultiplier: 1.2,
      gasPrice: 350000000000,
      loggingEnabled: true,
    },
    arbitrum: {
      url: "https://arb1.arbitrum.io/rpc",
      accounts: [`${process.env.PRIVATE_KEY}`],
      chainId: 42161,
      gas: 'auto',
      gasMultiplier: 1.2,
      gasPrice: 'auto',
      loggingEnabled: true,
    },
    kava: {
      url: "https://evm.kava.io", // public infura endpoint
      chainId: 2222,
      gas: 'auto',
      gasMultiplier: 1.2,
      gasPrice: 'auto',
      accounts: [`${process.env.PRIVATE_KEY}`],
      loggingEnabled: true,
    },
    metis: {
      url: "https://andromeda.metis.io/?owner=1088", // public endpoint
      chainId: 1088,
      gas: 'auto',
      gasMultiplier: 1.2,
      gasPrice: 'auto',
      accounts: [`${process.env.PRIVATE_KEY}`],
      loggingEnabled: true,
    },
  },
  mocha: {
    timeout: 100000,
  },
  etherscan: {
    apiKey: {
      mainnet: `${process.env.ETHERSCAN_API_KEY}`,
      bsc: `${process.env.BSCSCAN_API_KEY}`,
      avalanche: `${process.env.AVASCAN_API_KEY}`,
      polygon: `${process.env.POLIGONSCAN_API_KEY}`,
      opera: `${process.env.FTMSCAN_API_KEY}`,
      arbitrumOne: `${process.env.ARBISCAN_API_KEY}`,
      metis: "metis",
    },
    customChains: [
      {
        network: "metis",
        chainId: 1088,
        urls: {
          apiURL: "https://api.routescan.io/v2/network/mainnet/evm/1088/etherscan",
          browserURL: "https://andromeda-explorer.metis.io"
        }
      }
    ]
  }
};

export default config;
