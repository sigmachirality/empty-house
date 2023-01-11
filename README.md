# Empty House

## How to Run This Project

Circuits are written in circom, and we use the hardhat-circom plugin to generate verifier smart contracts. We use hardhat for local smart contract and script development. The frontend is built using React, Vite, Tailwind, and consumes our smart contracts and circuits using wagmi/rainbowkit and snarkjs respectively. 

Before starting, complete a Phase 1 trusted setup ceremony or download the results of a completed ceremony.

### A Note About Trusted Setup

We recommend using one of the `.ptau` files generated from the [Polygon Hermez](https://blog.hermez.io/polygon-hermez-team/) team's ceremony, which can be found [here](https://www.dropbox.com/sh/mn47gnepqu88mzl/AACaJkBU7mmCq8uU8ml0-0fma?dl=0). For more information on why this necessary, see this [writeup](https://github.com/projectsophon/hardhat-circom#powers-of-tau). We recommend using `powersOfTau28_hez_final_20.ptau` for a good tradeoff between the number of constraints supported and file size.

Copy this file into the directory `circuits/ptau` (make it if it does not exist).

### Local Dev Setup

#### Quickstart

```bash
yarn --dev
yarn compile && yarn deploy
yarn dev
```

#### Detailed Process

Starting at repo root:

```bash
yarn --dev
```

Compile circom (generate .wasm and .zkey files).

```bash
yarn hardhat circom --verbose
```

Compile smart contracts (generate artifacts)

```bash
yarn hardhat compile
```

Start a local blockchain

```bash
yarn hardhat node
```

In a new terminal, deploy game smart contracts.

```bash
yarn hardhat run --network localhost scripts/deploy.ts
```

Update the `.env` file in `/frontend` with the updated contract addresses.

Next, start a local blockchain.

```
yarn hardhat node
```

Start the frontend dev server.

```
cd frontend && yarn dev
```

Happy hacking!
