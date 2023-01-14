import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers } from "hardhat";
import { int } from "hardhat/internal/core/params/argumentTypes";
import { BigNumber, ContractReceipt } from "ethers";
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

describe("GameManager", function () {
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

    // deploy the GameManager contract
    const GameManager = await ethers.getContractFactory("GameManager");
    const gameManager = await GameManager.deploy(mentalPoker.address);
    await gameManager.deployed();
    console.log(
        `GameManager.sol deployed to ${gameManager.address}. Time: ${Date.now()}`
    );

    return {encryptVerifier, decryptVerifier, keyAggregateVerifier, mentalPoker, gameManager }
  }

  describe("Initial state", function () {
    // test 1 
    it("Example round w fold", async function () {
        const { encryptVerifier, decryptVerifier, keyAggregateVerifier, mentalPoker, gameManager } = await loadFixture(deployFixture);
        // create a new game with p1
        const bob = hardhat_default_addresses[0];
            // create the signer instance
        const bobSigner = await ethers.getSigner(bob);

        const alice = hardhat_default_addresses[1];
        const aliceSigner = await ethers.getSigner(alice);

        // create a game with msg.value = 0.5 eth and expect an emitted event "GameCreated" with lobby 0, blind 0.5eth, 1 player
        const gameTx = await expect(gameManager.connect(bobSigner).createNewGame({ value: ethers.utils.parseEther("0.5") })).to.emit(gameManager, "GameCreated").withArgs(0, ethers.utils.parseEther("0.5"), 1); // msg.value = 1 eth 
        
        // test the getCurrentGlobalGameCounter
        // const currentGameCounterView = await expect(gameManager.getCurrentGlobalGameCounter()).to.equal(0);

        // test the getBetSize
        // const betView = await expect(gameManager.getBetSize(0, bob)).to.equal(ethers.utils.parseEther("0.5"));

        // p2 joins
        const gameTx2 = await expect(gameManager.connect(aliceSigner).joinGame(0, { value: ethers.utils.parseEther("0.5") })).to.emit(gameManager, "GameJoined").withArgs(0, alice); // msg.value = 1 eth 

        // start the game
        const gameTx3 = await expect(gameManager.connect(bobSigner).startGame(0)).to.emit(gameManager, "GameStarted").withArgs(0);
        
        // do the card shuffling and dealing stuff here
        // add a shuffle with 2 players to the contract
        // const shuffleTx = await mentalPoker.newShuffle(hardhat_default_addresses.slice(0,3));
        // const rc = await shuffleTx.wait();
        // const shuffleEvent = rc.events!.find(event => event.event === 'NewShuffle');
        // expect(shuffleEvent).to.not.equal(undefined);
        // const [shuffleNum, playerAddresses] = shuffleEvent!.args;
        
        // // the first shuffle started on the smart contract should have id=0
        // expect(shuffleNum).to.equal(0);
        
        // // the initial aggregate key should be the identity element
        // expect(await mentalPoker.getCurrentAggregateKey(shuffleNum)).to.equal(BigNumber.from(1));
        
        // // player numbers
        // expect(await mentalPoker.getPlayerNumber(shuffleNum, hardhat_default_addresses[0])).to.equal(0);
        // expect(await mentalPoker.getPlayerNumber(shuffleNum, hardhat_default_addresses[1])).to.equal(1);

        // after they see their cards
        // p1 raises
        const gameTx4 = await expect(gameManager.connect(bobSigner).raise(0, { value: ethers.utils.parseEther("0.5") })).to.emit(gameManager, "GameRaised").withArgs(0, ethers.utils.parseEther("0.5")); // msg.value = 1 eth 

        // p2 folds
        const gameTx5 = await expect(gameManager.connect(aliceSigner).fold(0)).to.emit(gameManager, "GameCompleted").withArgs(0, ethers.utils.parseEther("1.5"), alice, bob);

    });
    it("Example round w raise", async function () {
        const { encryptVerifier, decryptVerifier, keyAggregateVerifier, mentalPoker, gameManager } = await loadFixture(deployFixture);
        // create a new game with p1
        const bob = hardhat_default_addresses[0];
            // create the signer instance
        const bobSigner = await ethers.getSigner(bob);

        const alice = hardhat_default_addresses[1];
        const aliceSigner = await ethers.getSigner(alice);

        // create a game with msg.value = 0.5 eth and expect an emitted event "GameCreated" with lobby 0, blind 0.5eth, 1 player
        const gameTx = await expect(gameManager.connect(bobSigner).createNewGame({ value: ethers.utils.parseEther("0.5") })).to.emit(gameManager, "GameCreated").withArgs(0, ethers.utils.parseEther("0.5"), 1); // msg.value = 1 eth 
        
        // test the getCurrentGlobalGameCounter
        // const currentGameCounterView = await expect(gameManager.getCurrentGlobalGameCounter()).to.equal(0);

        // test the getBetSize
        // const betView = await expect(gameManager.getBetSize(0, bob)).to.equal(ethers.utils.parseEther("0.5"));

        // p2 joins
        const gameTx2 = await expect(gameManager.connect(aliceSigner).joinGame(0, { value: ethers.utils.parseEther("0.5") })).to.emit(gameManager, "GameJoined").withArgs(0, alice); // msg.value = 1 eth 

        // start the game
        const gameTx3 = await expect(gameManager.connect(bobSigner).startGame(0)).to.emit(gameManager, "GameStarted").withArgs(0);
        
        // do the card shuffling and dealing stuff here
        // add a shuffle with 2 players to the contract
        // const shuffleTx = await mentalPoker.newShuffle(hardhat_default_addresses.slice(0,3));
        // const rc = await shuffleTx.wait();
        // const shuffleEvent = rc.events!.find(event => event.event === 'NewShuffle');
        // expect(shuffleEvent).to.not.equal(undefined);
        // const [shuffleNum, playerAddresses] = shuffleEvent!.args;
        
        // // the first shuffle started on the smart contract should have id=0
        // expect(shuffleNum).to.equal(0);
        
        // // the initial aggregate key should be the identity element
        // expect(await mentalPoker.getCurrentAggregateKey(shuffleNum)).to.equal(BigNumber.from(1));
        
        // // player numbers
        // expect(await mentalPoker.getPlayerNumber(shuffleNum, hardhat_default_addresses[0])).to.equal(0);
        // expect(await mentalPoker.getPlayerNumber(shuffleNum, hardhat_default_addresses[1])).to.equal(1);

        // after they see their cards
        // p1 raises
        const gameTx4 = await expect(gameManager.connect(bobSigner).raise(0, { value: ethers.utils.parseEther("0.5") })).to.emit(gameManager, "GameRaised").withArgs(0, ethers.utils.parseEther("0.5")); // msg.value = 1 eth 

        // p2 raises
        const gameTx5 = await expect(gameManager.connect(aliceSigner).raise(0, {value: ethers.utils.parseEther("0.5")})).to.emit(gameManager, "GameMatched").withArgs(0, ethers.utils.parseEther("0.5"));

    });
  });
});

    // // expect an emitted event
    // const gamedJoinedEvent = await gameTx2.wait();
    // expect(gameCreatedEvent.events[0]!.args.gameLobbyNumber).to.equal(0);
    // expect(gameCreatedEvent.events[0]!.args.player).to.equal(alice);

    //   // add a shuffle with 2 players to the contract
    //   const shuffleTx = await mentalPoker.newShuffle(hardhat_default_addresses.slice(0,3));
    //   const rc = await shuffleTx.wait();
    //   const shuffleEvent = rc.events!.find(event => event.event === 'NewShuffle');
    //   expect(shuffleEvent).to.not.equal(undefined);
    //   const [shuffleNum, playerAddresses] = shuffleEvent!.args;

    //   // the first shuffle started on the smart contract should have id=0
    //   expect(shuffleNum).to.equal(0);
      
    //   // the initial aggregate key should be the identity element
    //   expect(await mentalPoker.getCurrentAggregateKey(shuffleNum)).to.equal(BigNumber.from(1));

    //   // player numbers
    //   expect(await mentalPoker.getPlayerNumber(shuffleNum, hardhat_default_addresses[0])).to.equal(0);
    //   expect(await mentalPoker.getPlayerNumber(shuffleNum, hardhat_default_addresses[1])).to.equal(1);
    //   expect(await mentalPoker.getPlayerNumber(shuffleNum, hardhat_default_addresses[2])).to.equal(2);

