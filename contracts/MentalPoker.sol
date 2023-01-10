// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "./interfaces/IEncryptVerifier.sol";
import "./interfaces/IDecryptVerifier.sol";
import "./interfaces/IKeyAggregateVerifier.sol";

/**
 * @title MentalPoker
 * @dev Distribute cards for mental poker
 * @custom:dev-run-script ./scripts/deploy_with_ethers.ts
 */
contract MentalPoker {

    struct MentalPokerInvocation {
        address[5] players;
        uint256 aggregatePublicKey; // should not be uint256 -- the field F_r is a prime field
        uint256[52][2] encryptedShuffledDeck; // should not be uint256
    }

    struct KeyAggregateProofData {
        uint[2] a;
        uint[2][2] b;
        uint[2] c;
        uint pk;
    }

    struct EncryptProofData {
        uint[2] a;
        uint[2][2] b;
        uint[2] c;
        uint[25] input;
    }

    struct DecryptProofData {
        uint[2] a;
        uint[2][2] b;
        uint[2] c;
        uint[4] input;
    }

    // for the general case:
    // Counters.Counter private _invocationCounter;
    // mapping (uint256 => MentalPokerInvocation) invocations;
    MentalPokerInvocation invocation;

    IKeyAggregateVerifier keyAggregateVerifier;
    IEncryptVerifier encryptVerifier;
    IDecryptVerifier decryptVerifier;

    constructor(
        address _keyAggregateVerifier,
        address _encryptVerifier,
        address _decryptVerifier
    ) {
        keyAggregateVerifier = IKeyAggregateVerifier(_keyAggregateVerifier);
        encryptVerifier = IEncryptVerifier(_encryptVerifier);
        decryptVerifier = IDecryptVerifier(_decryptVerifier);

        // initialize a single mental poker
        invocation = MentalPokerInvocation({
            players: [
                0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266,
                0x70997970C51812dc3A010C7d01b50e0d17dc79C8,
                0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC,
                0x90F79bf6EB2c4f870365E785982E1f101E93b906,
                0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65
            ],
            aggregatePublicKey: 1,
            encryptedShuffledDeck: [
                ["1", "2"],
                ["1", "3"],
                ["1", "4"],
                ["1", "5"],
                ["1", "6"],
                ["1", "7"]
            ]
        });
    }

    /**
     * @dev Store value in variable
     * @param num value to store
     */
    function updateAggregateKey(
        KeyAggregateProofData memory _keyAggregateProofData
    ) public {
        // verify that the player knows the private key that derived their public key
        require(keyAggregateVerifier.verifyProof(
            _keyAggregateProofData.a,
            _keyAggregateProofData.b,
            _keyAggregateProofData.c,
            [_keyAggregateProofData.pk]),
            "Invalid proof!"
        );

        // update the aggregated public key on the smart contract
        invocation.aggregatePublicKey = invocation.aggregatePublicKey * _keyAggregateProofData.pk;
    }

    /**
     * @dev Return value 
     * @return value of 'number'
     */
    function encrypt(
        EncryptProofData memory _encryptProofData
    ) public {
        // verify that the inputted deck is the shuffled and correctly-encrypted
        // version of the deck from the last round
        require(encryptVerifier.verifyProof(
            _encryptProofData.a,
            _encryptProofData.b,
            _encryptProofData.c,
            _encryptProofData.input),
            "Invalid proof!"
        );

        // update the deck on the smart contract
        invocation.encryptedShuffledDeck = invocation.encryptedShuffledDeck;
    }

    /**
     * @dev Return value 
     * @return value of 'number'
     */
    function decrypt(
        DecryptProofData memory _decryptProofData
    ) public {
        // verify that the one-step-more-decrypted card was produced by taking the
        // corresponding card on the smart contract and running the decryption
        // algorithm correctly
        require(decryptVerifier.verifyProof(
            _decryptProofData.a,
            _decryptProofData.b,
            _decryptProofData.c,
            _decryptProofData.input),
            "Invalid proof!"
        );

        // update the card on the smart contract
        invocation.encryptedShuffledDeck = invocation.encryptedShuffledDeck;
    }
}
