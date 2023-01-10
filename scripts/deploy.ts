import { ethers } from "hardhat";

async function main() {
  // deploy the encrypt verifier
  const EncryptVerifier = await ethers.getContractFactory("EncryptVerifier");
  const encryptVerifier = await EncryptVerifier.deploy();
  await encryptVerifier.deployed();
  console.log(
    `BoardsetupVerifier.sol deployed to ${encryptVerifier.address}. Time: ${Date.now()}`
  );

  // deploy the decrypt verifier
  const DecryptVerifier = await ethers.getContractFactory("DecryptVerifier");
  const decryptVerifier = await DecryptVerifier.deploy();
  await decryptVerifier.deployed();
  console.log(
    `BoardsetupVerifier.sol deployed to ${decryptVerifier.address}. Time: ${Date.now()}`
  );

  // deploy the key aggregate verifier
  const KeyAggregateVerifier = await ethers.getContractFactory("KeyAggregateVerifier");
  const keyAggregateVerifier = await KeyAggregateVerifier.deploy();
  await keyAggregateVerifier.deployed();
  console.log(
    `BoardsetupVerifier.sol deployed to ${keyAggregateVerifier.address}. Time: ${Date.now()}`
  );

  // deploy the main contract
  const MentalPoker = await ethers.getContractFactory("MentalPoker");
  const mentalPoker = await MentalPoker.deploy(
    keyAggregateVerifier.address,
    encryptVerifier.address,
    decryptVerifier.address,
  );
  await mentalPoker.deployed();
  console.log(
    `MentalPoker.sol deployed to ${mentalPoker.address}. Time: ${Date.now()}`
  );

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
