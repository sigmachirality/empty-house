import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "hardhat-circom";

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: "0.8.17",
      },
      {
        version: "0.6.12",
        settings: {},
      },
    ],
    overrides: {
      "contracts/EncryptVerifier.sol": {
        version: "0.6.12",
        settings: { }
      },
      "contracts/DecryptVerifier.sol": {
        version: "0.6.12",
        settings: { }
      },
      "contracts/KeyAggregateVerifier.sol": {
        version: "0.6.12",
        settings: { }
      },
    }
  },
  circom: {
    // (optional) Base path for input files, defaults to `./circuits/`
    inputBasePath: "./circuits",
    // (required) The final ptau file, relative to inputBasePath, from a Phase 1 ceremony
    ptau: "./ptau/powersOfTau28_hez_final_20.ptau",
    // (required) Each object in this array refers to a separate circuit
    circuits: [
      { name: "key_aggregate" },
      { name: "encrypt" },
      { name: "decrypt" }
    ],
  },
};


export default config;
