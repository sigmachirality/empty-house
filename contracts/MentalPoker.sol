// SPDX-License-Identifier: GPL-3.0

pragma solidity >0.6.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "./interfaces/IEncryptVerifier.sol";
import "./interfaces/IDecryptVerifier.sol";
import "./interfaces/IKeyAggregateVerifier.sol";

/**
 * @title MentalPoker
 * @dev Distribute cards for mental poker
 */
contract MentalPoker {

    struct MentalPokerShuffle {
        mapping(address => uint) playerNumbers;
        mapping(address => uint256) playerPublicKeys;
        uint256 aggregatePublicKey;
        uint256[2][6] encryptedShuffledDeck;
    }

    struct KeyAggregateProofData {
        uint[2] a;
        uint[2][2] b;
        uint[2] c;
        uint old_aggk;
        uint new_aggk;
        uint pk;
    }

    struct EncryptProofData {
        uint[2] a;
        uint[2][2] b;
        uint[2] c;
        uint[2][6] input_tuples; // [[2, 3, 4, 6, 7], []]
        uint[2][6] output_tuples;
        uint aggk;
    }

    struct DecryptProofData {
        uint[2] a;
        uint[2][2] b;
        uint[2] c;
        uint[2] masked_card;
        uint unmasked_card;
        uint pk;
    }

    event NewShuffle(uint _shuffleNum, address[] _players);
    event AggregateKeyUpdated(uint _playerNum, uint _newAgg);
    event DeckEncryptedShuffled(uint _playerNum, uint _nextPlayerNum);
    event CardDecrypted(uint _cardNum, uint _playerNum, uint _nextPlayerNum);

    // TODO: change the shuffleCounter to a Counter (@OpenZeppelin)
    // https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Counters.sol
    uint shuffleCounter;
    mapping (uint256 => MentalPokerShuffle) shuffles;

    IKeyAggregateVerifier keyAggregateVerifier;
    IEncryptVerifier encryptVerifier;
    IDecryptVerifier decryptVerifier;

    constructor(
        address _keyAggregateVerifier,
        address _encryptVerifier,
        address _decryptVerifier
    ) public {
        // connect this contract to the verifiers for the zero-knowledge proofs
        keyAggregateVerifier = IKeyAggregateVerifier(_keyAggregateVerifier);
        encryptVerifier = IEncryptVerifier(_encryptVerifier);
        decryptVerifier = IDecryptVerifier(_decryptVerifier);

        shuffleCounter = 0;
    }

    function getPlayerNumber(uint _shuffleNum, address playerAddress) public view returns (uint) {
        return shuffles[_shuffleNum].playerNumbers[playerAddress];
    }

    function getCurrentAggregateKey(uint _shuffleNum) public view returns (uint256) {
        return shuffles[_shuffleNum].aggregatePublicKey;
    }

    function getDeck(uint _shuffleNum) public view returns (uint256[2][6] memory) {
        return shuffles[_shuffleNum].encryptedShuffledDeck;
    }

    function getCard(uint _shuffleNum, uint256 cardNumber) public view returns (uint256[2] memory) {
        return shuffles[_shuffleNum].encryptedShuffledDeck[cardNumber];
    }

    /**
     * @dev
     */
    function newShuffle(
        address[] memory playerAddresses
    ) public returns (uint) {
        uint256[2][6] memory _encryptedShuffledDeck = [
            [uint256(1), uint256(2)],
            [uint256(1), uint256(3)],
            [uint256(1), uint256(4)],
            [uint256(1), uint256(5)],
            [uint256(1), uint256(6)],
            [uint256(1), uint256(7)]
        ];

        // initialize a new shuffle
        shuffles[shuffleCounter] = MentalPokerShuffle({
            aggregatePublicKey: uint(1),
            encryptedShuffledDeck: _encryptedShuffledDeck
        });
        
        // assign numbers to players
        for(uint i = 0; i < playerAddresses.length; i++) {
            shuffles[shuffleCounter].playerNumbers[playerAddresses[i]] = i;
        }

        // increment the counter
        shuffleCounter++;

        emit NewShuffle(shuffleCounter-1, playerAddresses);
        return shuffleCounter-1;
    }

    /**
     * @dev
     */
    function updateAggregateKey(
        uint _shuffleNum,
        KeyAggregateProofData memory _keyAggregateProofData
    ) public returns (uint) {
        // get the shuffle that the caller is referring to
        MentalPokerShuffle storage shuffle = shuffles[_shuffleNum];

        // the aggregated public key that the player started with should be 
        // the aggregated public key that is stored in the smart contract.
        require(_keyAggregateProofData.old_aggk == shuffle.aggregatePublicKey);

        // verify that the player knows the private key that derived their public key
        // and that the new aggregated public key is calculate correctly.
        require(keyAggregateVerifier.verifyProof(
            _keyAggregateProofData.a,
            _keyAggregateProofData.b,
            _keyAggregateProofData.c,
            [_keyAggregateProofData.new_aggk,
                _keyAggregateProofData.pk,
                _keyAggregateProofData.old_aggk]),
            "Invalid proof (updateAggregateKey)!"
        );

        // save the caller's public key. the caller will be required to
        // use the same public key while decrypting the cards later.
        shuffle.playerPublicKeys[msg.sender] = _keyAggregateProofData.pk;

        // update the aggregated public key on the smart contract.
        shuffle.aggregatePublicKey = _keyAggregateProofData.new_aggk;

        // emit an event
        emit AggregateKeyUpdated(shuffle.playerNumbers[msg.sender], shuffle.aggregatePublicKey);

        return shuffle.playerNumbers[msg.sender];
    }

    /**
     * @dev
     */
    function encrypt(
        uint _shuffleNum,
        EncryptProofData memory _encryptProofData
    ) public {
        // get the shuffle that the caller is referring to
        MentalPokerShuffle storage shuffle = shuffles[_shuffleNum];

        // the caller should 1) encrypt-shuffle the latest version of the
        // encrypt-shuffled deck and 2) use the aggregate public key on the
        // smart contract.
        require(keccak256(abi.encode(_encryptProofData.input_tuples))
                == keccak256(abi.encode(shuffle.encryptedShuffledDeck)));
        require(_encryptProofData.aggk == shuffle.aggregatePublicKey);

        // TODO: check that the order of the flattening below is correct
        /* flatten the public zk data to pass in to verifyProof */
        uint[25] memory flattened;
        // copy the output tuples
        for(uint i = 0; i < 6; i++) {
            flattened[2*i] =  _encryptProofData.output_tuples[i][0];
            flattened[2*i+1] = _encryptProofData.output_tuples[i][1];
        }
        // copy the pk
        flattened[12] = _encryptProofData.aggk;
        // copy the input tuples
        for(uint i = 6; i < 12; i++) {
            flattened[2*i+1] = _encryptProofData.input_tuples[i-6][0];
            flattened[2*i+2] = _encryptProofData.input_tuples[i-6][1];
        }

        // verify that the inputted deck is the shuffled and correctly-encrypted
        // version of the deck from the last round.
        require(encryptVerifier.verifyProof(
            _encryptProofData.a,
            _encryptProofData.b,
            _encryptProofData.c,
            flattened),
            "Invalid proof (encrypt)!"
        );

        // update the deck on the smart contract.
        shuffle.encryptedShuffledDeck = _encryptProofData.output_tuples;

        // signal the next player
        uint nextPlayerNum = (shuffle.playerNumbers[msg.sender] + 1) % 5;
        emit DeckEncryptedShuffled(shuffle.playerNumbers[msg.sender], nextPlayerNum);
    }

    /**
     * @dev  
     */
    function decrypt(
        uint _shuffleNum,
        uint256 _cardNum,
        DecryptProofData memory _decryptProofData
    ) public {
        // get the shuffle that the caller is referring to
        MentalPokerShuffle storage shuffle = shuffles[_shuffleNum];

        // the caller should 1) encrypt-shuffle the latest version of the
        // encrypt-shuffled card and 2) use the same secret key that it used
        // during the key aggregation process.
        require(keccak256(abi.encode(shuffle.encryptedShuffledDeck[_cardNum]))
                == keccak256(abi.encode(_decryptProofData.masked_card)));
        require(shuffle.playerPublicKeys[msg.sender] == _decryptProofData.pk);

        // TODO: check that the order of the flattening below is correct
        /* flatten the public zk data to pass in to verifyProof */
        uint[4] memory flattened = [
            _decryptProofData.pk,
            _decryptProofData.unmasked_card,
            _decryptProofData.masked_card[0],
            _decryptProofData.masked_card[1]
        ];

        // verify that the one-step-more-decrypted card was produced by taking the
        // corresponding card on the smart contract and running the decryption
        // algorithm correctly.
        require(decryptVerifier.verifyProof(
            _decryptProofData.a,
            _decryptProofData.b,
            _decryptProofData.c,
            flattened),
            "Invalid proof (decrypt)!"
        );

        // update the card on the smart contract
        // the rest of the deck stays the same.
        uint[2] memory newCard = [_decryptProofData.masked_card[0], _decryptProofData.unmasked_card];
        shuffle.encryptedShuffledDeck[_cardNum] = newCard;

        uint nextPlayerNum = (shuffle.playerNumbers[msg.sender] + 1) % 5;
        emit DeckEncryptedShuffled(shuffle.playerNumbers[msg.sender], nextPlayerNum);
    }
}
