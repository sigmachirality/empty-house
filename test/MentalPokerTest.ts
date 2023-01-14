import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers } from "hardhat";
import { int } from "hardhat/internal/core/params/argumentTypes";
import { BigNumber } from "ethers";
import { groth16 } from "snarkjs";

const ENCRYPT_WASM_FILE_PATH = "circuits/encrypt.wasm";
const ENCRYPT_ZKEY_FILE_PATH = "circuits/encrypt.zkey";
const DECRYPT_WASM_FILE_PATH = "circuits/decrypt.wasm";
const DECRYPT_ZKEY_FILE_PATH = "circuits/decrypt.zkey";
const KEYAGGREGATE_WASM_FILE_PATH = "circuits/key_aggregate.wasm";
const KEYAGGREGATE_ZKEY_FILE_PATH = "circuits/key_aggregate.zkey";

import { generateProof } from "./utils/snark-utils";


const hardhat_default_addresses = [
  '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266',
  '0x70997970C51812dc3A010C7d01b50e0d17dc79C8',
  '0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC',
  '0x90F79bf6EB2c4f870365E785982E1f101E93b906',
  '0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65',
  '0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc',
  '0x976EA74026E726554dB657fA54763abd0C3a0aa9',
  '0x14dC79964da2C08b23698B3D3cc7Ca32193d9955',
  '0x23618e81E3f5cdF7f54C3d65f7FBc0aBf5B21E8f',
  '0xa0Ee7A142d267C1f36714E4a8F75612F20a79720',
  '0xBcd4042DE499D14e55001CcbB24a551F3b954096',
  '0x71bE63f3384f5fb98995898A86B02Fb2426c5788',
  '0xFABB0ac9d68B0B445fB7357272Ff202C5651694a',
  '0x1CBd3b2770909D4e10f157cABC84C7264073C9Ec',
  '0xdF3e18d64BC6A983f673Ab319CCaE4f1a57C7097',
  '0xcd3B766CCDd6AE721141F452C550Ca635964ce71',
  '0x2546BcD3c84621e976D8185a91A922aE77ECEc30',
  '0xbDA5747bFD65F08deb54cb465eB87D40e51B197E',
  '0xdD2FD4581271e230360230F9337D5c0430Bf44C0',
  '0x8626f6940E2eb28930eFb4CeF49B2d1F2C9C1199'
];

describe("MentalPoker", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployFixture() {
    // deploy the encrypt verifier
    const EncryptVerifier = await ethers.getContractFactory("contracts/EncryptVerifier.sol:Verifier");
    const encryptVerifier = await EncryptVerifier.deploy();
    await encryptVerifier.deployed();
    console.log(
      `EncryptVerifier.sol deployed to ${encryptVerifier.address}. Time: ${Date.now()}`
    );

    // deploy the decrypt verifier
    const DecryptVerifier = await ethers.getContractFactory("contracts/DecryptVerifier.sol:Verifier");
    const decryptVerifier = await DecryptVerifier.deploy();
    await decryptVerifier.deployed();
    console.log(
      `DecryptVerifier.sol deployed to ${decryptVerifier.address}. Time: ${Date.now()}`
    );

    // deploy the key aggregate verifier
    const KeyAggregateVerifier = await ethers.getContractFactory("contracts/KeyAggregateVerifier.sol:Verifier");
    const keyAggregateVerifier = await KeyAggregateVerifier.deploy();
    await keyAggregateVerifier.deployed();
    console.log(
      `KeyAggregateVerifier.sol deployed to ${keyAggregateVerifier.address}. Time: ${Date.now()}`
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

    return { mentalPoker }
  }

  describe("Initial state", function () {
    it("Initial values", async function () {
      const { mentalPoker } = await loadFixture(deployFixture);

      // add a shuffle with 3 players to the contract
      const shuffleTx = await mentalPoker.newShuffle(hardhat_default_addresses.slice(0,3));
      const rc = await shuffleTx.wait();
      const shuffleEvent = rc.events!.find(event => event.event === 'NewShuffle');
      expect(shuffleEvent).to.not.equal(undefined);
      const [shuffleNum, playerAddresses] = shuffleEvent!.args;

      // the first shuffle started on the smart contract should have id=0
      expect(shuffleNum).to.equal(0);
      
      // the initial aggregate key should be the identity element
      expect(await mentalPoker.getCurrentAggregateKey(shuffleNum)).to.equal(BigNumber.from(1));

      // player numbers
      expect(await mentalPoker.getPlayerNumber(shuffleNum, hardhat_default_addresses[0])).to.equal(0);
      expect(await mentalPoker.getPlayerNumber(shuffleNum, hardhat_default_addresses[1])).to.equal(1);
      expect(await mentalPoker.getPlayerNumber(shuffleNum, hardhat_default_addresses[2])).to.equal(2);
    });

    it("Initial values", async function () {
      const { mentalPoker } = await loadFixture(deployFixture);
    
      // start 3 shuffles
      for(var i = 0; i < 3; i++) {
        const shuffleTx = await mentalPoker.newShuffle(hardhat_default_addresses.slice(3*i,3*i+3));
        const rc = await shuffleTx.wait();
        const shuffleEvent = rc.events!.find(event => event.event === 'NewShuffle');
        expect(shuffleEvent).to.not.equal(undefined);
        const [shuffleNum, playerAddresses] = shuffleEvent!.args;

        expect(shuffleNum).to.equal(i);
      }

      // complete the encrypt-shuffle process for the 1. shuffle
      // Generate witness and proof


      // Update aggregate key with new value
      const [owner, otherAccount] = await ethers.getSigners();

      const circuitInputs = {
        sk: 4242,
        old_aggk: BigInt(1)
      }
      const proofData = await generateProof(
        circuitInputs,
        KEYAGGREGATE_WASM_FILE_PATH,
        KEYAGGREGATE_ZKEY_FILE_PATH
      );

      const [newAggregateKey, pk] = proofData.inputs;
      const shuffleTx = await mentalPoker.connect(otherAccount).updateAggregateKey(
        0,
        {
          a: proofData.a,
          b: proofData.b,
          c: proofData.c,
          old_aggk: BigInt(1),
          new_aggk: newAggregateKey,
          pk: pk,
        }
      );

      const rc = await shuffleTx.wait();
      const shuffleEvent = rc.events!.find(event => event.event === 'AggregateKeyUpdated');
      expect(shuffleEvent).to.not.equal(undefined);
      const [_shuffleNum, playerNum, _newAgg, keyAggregationCompleted] = shuffleEvent!.args;

      
    });
  });

  // describe("Withdrawals", function () {
  //   describe("Validations", function () {
  //     it("Should revert with the right error if called too soon", async function () {
  //       const { lock } = await loadFixture(deployOneYearLockFixture);

  //       await expect(lock.withdraw()).to.be.revertedWith(
  //         "You can't withdraw yet"
  //       );
  //     });

  //     it("Should revert with the right error if called from another account", async function () {
  //       const { lock, unlockTime, otherAccount } = await loadFixture(
  //         deployOneYearLockFixture
  //       );

  //       // We can increase the time in Hardhat Network
  //       await time.increaseTo(unlockTime);

  //       // We use lock.connect() to send a transaction from another account
  //       await expect(lock.connect(otherAccount).withdraw()).to.be.revertedWith(
  //         "You aren't the owner"
  //       );
  //     });

  //     it("Shouldn't fail if the unlockTime has arrived and the owner calls it", async function () {
  //       const { lock, unlockTime } = await loadFixture(
  //         deployOneYearLockFixture
  //       );

  //       // Transactions are sent using the first signer by default
  //       await time.increaseTo(unlockTime);

  //       await expect(lock.withdraw()).not.to.be.reverted;
  //     });
  //   });

  //   describe("Events", function () {
  //     it("Should emit an event on withdrawals", async function () {
  //       const { lock, unlockTime, lockedAmount } = await loadFixture(
  //         deployOneYearLockFixture
  //       );

  //       await time.increaseTo(unlockTime);

  //       await expect(lock.withdraw())
  //         .to.emit(lock, "Withdrawal")
  //         .withArgs(lockedAmount, anyValue); // We accept any value as `when` arg
  //     });
  //   });

  //   describe("Transfers", function () {
  //     it("Should transfer the funds to the owner", async function () {
  //       const { lock, unlockTime, lockedAmount, owner } = await loadFixture(
  //         deployOneYearLockFixture
  //       );

  //       await time.increaseTo(unlockTime);

  //       await expect(lock.withdraw()).to.changeEtherBalances(
  //         [owner, lock],
  //         [lockedAmount, -lockedAmount]
  //       );
  //     });
  //   });
  // });
});

