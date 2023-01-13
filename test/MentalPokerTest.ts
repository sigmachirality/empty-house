import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers } from "hardhat";
import { int } from "hardhat/internal/core/params/argumentTypes";
import { BigNumber } from "ethers";

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





    return { mentalPoker, encryptVerifier, decryptVerifier, keyAggregateVerifier }
  }

  describe("Initial state", function () {
    it("Initial values", async function () {
      const { mentalPoker, encryptVerifier, decryptVerifier, keyAggregateVerifier } = await loadFixture(deployFixture);

      // add a shuffle to the contract
      const hardhat_default_addresses = [
        '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266',
        '0x70997970C51812dc3A010C7d01b50e0d17dc79C8',
        '0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC',
        '0x90F79bf6EB2c4f870365E785982E1f101E93b906',
        '0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65'
      ];

      const shuffleTx = await mentalPoker.newShuffle(hardhat_default_addresses);
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

      // initial deck
      
    });

    it("Default player numbers", async function () {
      const { mentalPoker, encryptVerifier, decryptVerifier, keyAggregateVerifier } = await loadFixture(deployFixture);

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
