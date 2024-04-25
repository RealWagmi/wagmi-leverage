import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@matterlabs/hardhat-zksync-node";
import "@matterlabs/hardhat-zksync-deploy";
import "@matterlabs/hardhat-zksync-solc";
import "@matterlabs/hardhat-zksync-verify";

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

const config: HardhatUserConfig = {

  defaultNetwork: "zkLinkTestnet",
  zksolc: {
    version: "latest", // optional.
    settings: {
      // compilerPath: "zksolc",  // optional. Ignored for compilerSource "docker". Can be used if compiler is located in a specific folder
      // libraries: {}, // optional. References to non-inlinable libraries
      // missingLibrariesPath: "./.zksolc-libraries-cache/missingLibraryDependencies.json", // optional. This path serves as a cache that stores all the libraries that are missing or have dependencies on other libraries. A `hardhat-zksync-deploy` plugin uses this cache later to compile and deploy the libraries, especially when the `deploy-zksync:libraries` task is executed
      // isSystem: false, // optional.  Enables Yul instructions available only for zkSync system contracts and libraries
      // forceEvmla: false, // optional. Falls back to EVM legacy assembly if there is a bug with Yul
      optimizer: {
        enabled: true, // optional. True by default
        mode: 'z', // optional. 3 by default, z to optimize bytecode size
        fallback_to_optimizing_for_size: true, // optional. Try to recompile with optimizer mode "z" if the bytecode is too large
      },
      // contractsToCompile: ["FlashLoanAggregator"] //optional. Compile only specific contracts
    }
  },
  solidity: {
    version: "0.8.23",
  },
  networks: {
    hardhat: {
      zksync: true,
    },
    zkLinkMainnet: {
      url: "https://rpc.zklink.io",
      chainId: 810180,
      accounts: [`${process.env.PRIVATE_KEY}`],
      ethNetwork: "mainnet",
      zksync: true,
      verifyURL: " https://explorer.zklink.io/contract_verification",
    },
    zkLinkTestnet: {
      url: "https://sepolia.rpc.zklink.io",
      chainId: 810181,
      accounts: [`${process.env.PRIVATE_KEY}`],
      ethNetwork: "sepolia",
      zksync: true,
      verifyURL: "https://sepolia.explorer.zklink.io/contract_verification",
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
      base: `${process.env.BASE_API_KEY}`,
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
      },
      {
        network: "base",
        chainId: 8453,
        urls: {
          apiURL: "https://api.basescan.org/api",
          browserURL: "https://basescan.org"
        }
      }
    ]
  }
};

export default config;
