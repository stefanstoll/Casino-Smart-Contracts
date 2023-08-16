import { HardhatUserConfig } from "hardhat/config";
import '@typechain/hardhat';
import "@nomicfoundation/hardhat-ethers";
import '@nomicfoundation/hardhat-chai-matchers';
import "hardhat-deploy";
import "@nomicfoundation/hardhat-toolbox";
import 'solidity-coverage';
import "@nomicfoundation/hardhat-verify";

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.19",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
      chainId: 31337,
      forking: {
        enabled: true,
        url: 'https://goerli-rollup.arbitrum.io/rpc'',
      }
    },
    arbitrumGoerli: {
      url: 'https://goerli-rollup.arbitrum.io/rpc',
      chainId: 421613,
      //accounts: [ARBITRUM_GOERLI_TEMPORARY_PRIVATE_KEY]
    },
    arbitrumOne: {
      url: 'https://arb1.arbitrum.io/rpc',
      //accounts: [ARBITRUM_MAINNET_TEMPORARY_PRIVATE_KEY]
    },
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts"
  },
  mocha: {
    timeout: 40000
  },
  namedAccounts: {
    deployer: {
        default: 0, // here this will by default take the first account as deployer
    },
  },
  etherscan: {
    // Your API key for Etherscan
    // Obtain one at https://arbiscan.io/
    apiKey: {
      arbitrumGoerli: "YOUR_ARBISCAN_API_KEY_HERE",
      arbitrumOne: "YOUR_ARBISCAN_API_KEY_HERE",
    }
  }
};

export default config;
