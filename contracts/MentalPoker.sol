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

    struct MentalPokerPlayer {
        uint number;
        bool pkSubmitted;
        uint pk;
        bool encryptedShuffled;
        bool[52] cardDecrypted;
    }

    struct MentalPokerShuffle {
        mapping(address => bool) playerExists;
        mapping(address => MentalPokerPlayer) players;

        uint256 aggregatePublicKey;
        uint256[2][52] encryptedShuffledDeck;

        uint256 playerCount;
        uint256 keyAggregationCount;
        uint256 encryptShuffleCount;
        uint[52] cardDecryptCounts;
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
        uint[2] input_hashes;
        uint[2] output_hashes;
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
    event AggregateKeyUpdated(uint _shuffleNum, uint _playerNum, uint _newAgg, bool keyAggregationCompleted);
    event DeckEncryptedShuffled(uint _shuffleNum, uint _playerNum, bool encryptShuffleCompleted);
    event CardDecrypted(uint _shuffleNum, uint _cardNum, uint _playerNum, bool finalDecryptLeft);

    // TODO: change the shuffleCounter to a Counter (@OpenZeppelin)
    // https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Counters.sol
    uint shuffleCounter;
    mapping (uint256 => MentalPokerShuffle) shuffles;

    IKeyAggregateVerifier keyAggregateVerifier;
    IEncryptVerifier encryptVerifier;
    IDecryptVerifier decryptVerifier;

    modifier isPlayer(address supposedPlayer, uint _shuffleNum) {
        require(shuffles[_shuffleNum].playerExists[supposedPlayer]);
        _;
    }

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
        return shuffles[_shuffleNum].players[playerAddress].number;
    }

    function getCurrentAggregateKey(uint _shuffleNum) public view returns (uint256) {
        return shuffles[_shuffleNum].aggregatePublicKey;
    }

    function getDeck(uint _shuffleNum) public view returns (uint256[2][52] memory) {
        return shuffles[_shuffleNum].encryptedShuffledDeck;
    }

    function getCard(uint _shuffleNum, uint256 cardNumber) public view returns (uint256[2] memory) {
        return shuffles[_shuffleNum].encryptedShuffledDeck[cardNumber];
    }

    // TODO: should the bool functions below be private?
    function keyAggregationCompleted(uint _shuffleNum) public view returns (bool) {
        MentalPokerShuffle storage shuffle = shuffles[_shuffleNum];
        return shuffle.keyAggregationCount == shuffle.playerCount;
    }

    function encryptShuffleCompleted(uint _shuffleNum) public view returns (bool) {
        MentalPokerShuffle storage shuffle = shuffles[_shuffleNum];
        return shuffle.encryptShuffleCount == shuffle.playerCount;
    }

    function finalDecryptLeft(uint _shuffleNum, uint _cardNum) public view returns (bool) {
        MentalPokerShuffle storage shuffle = shuffles[_shuffleNum];
        return shuffle.cardDecryptCounts[_cardNum] == shuffle.playerCount - 1;
    }

    function cardDecrypted(uint _shuffleNum, uint _cardNum) public view returns (bool) {
        MentalPokerShuffle storage shuffle = shuffles[_shuffleNum];
        return shuffle.cardDecryptCounts[_cardNum] == shuffle.playerCount;
    }

    /**
     * @dev
     */
    function newShuffle(
        address[] memory playerAddresses
    ) public returns (uint) {
        uint256[2][52] memory _encryptedShuffledDeck = [
            [uint256(1), uint256(2)],
            [uint256(1), uint256(3)],
            [uint256(1), uint256(4)],
            [uint256(1), uint256(5)],
            [uint256(1), uint256(6)],
            [uint256(1), uint256(7)],
            [uint256(1), uint256(8)],
            [uint256(1), uint256(9)],
            [uint256(1), uint256(10)],
            [uint256(1), uint256(11)],
            [uint256(1), uint256(12)],
            [uint256(1), uint256(13)],
            [uint256(1), uint256(14)],
            [uint256(1), uint256(15)],
            [uint256(1), uint256(16)],
            [uint256(1), uint256(17)],
            [uint256(1), uint256(18)],
            [uint256(1), uint256(19)],
            [uint256(1), uint256(20)],
            [uint256(1), uint256(21)],
            [uint256(1), uint256(22)],
            [uint256(1), uint256(23)],
            [uint256(1), uint256(24)],
            [uint256(1), uint256(25)],
            [uint256(1), uint256(26)],
            [uint256(1), uint256(27)],
            [uint256(1), uint256(28)],
            [uint256(1), uint256(29)],
            [uint256(1), uint256(30)],
            [uint256(1), uint256(31)],
            [uint256(1), uint256(32)],
            [uint256(1), uint256(33)],
            [uint256(1), uint256(34)],
            [uint256(1), uint256(35)],
            [uint256(1), uint256(36)],
            [uint256(1), uint256(37)],
            [uint256(1), uint256(38)],
            [uint256(1), uint256(39)],
            [uint256(1), uint256(40)],
            [uint256(1), uint256(41)],
            [uint256(1), uint256(42)],
            [uint256(1), uint256(43)],
            [uint256(1), uint256(44)],
            [uint256(1), uint256(45)],
            [uint256(1), uint256(46)],
            [uint256(1), uint256(47)],
            [uint256(1), uint256(48)],
            [uint256(1), uint256(49)],
            [uint256(1), uint256(50)],
            [uint256(1), uint256(51)],
            [uint256(1), uint256(52)],
            [uint256(1), uint256(53)]
        ];

        // initialize a new shuffle
        shuffles[shuffleCounter] = MentalPokerShuffle({
            aggregatePublicKey: uint(1),
            encryptedShuffledDeck: _encryptedShuffledDeck,
            playerCount: playerAddresses.length,
            keyAggregationCount: 0,
            encryptShuffleCount: 0,
            cardDecryptCounts: [
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0)                
            ]
        });
        
        // create the players
        for(uint i = 0; i < playerAddresses.length; i++) {
            shuffles[shuffleCounter].players[playerAddresses[i]] = MentalPokerPlayer({
                number: i,
                pkSubmitted: false,
                pk: 0,
                encryptedShuffled: false,
                cardDecrypted: [
                    false,
                    false,
                    false,
                    false,
                    false,
                    false,
                    false,
                    false,
                    false,
                    false,
                    false,
                    false,
                    false,
                    false,
                    false,
                    false,
                    false,
                    false,
                    false,
                    false,
                    false,
                    false,
                    false,
                    false,
                    false,
                    false,
                    false,
                    false,
                    false,
                    false,
                    false,
                    false,
                    false,
                    false,
                    false,
                    false,
                    false,
                    false,
                    false,
                    false,
                    false,
                    false,
                    false,
                    false,
                    false,
                    false,
                    false,
                    false,
                    false,
                    false,
                    false,
                    false
                ]
            });

            shuffles[shuffleCounter].playerExists[playerAddresses[i]] = true;
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
    ) public isPlayer(msg.sender, _shuffleNum) returns (uint) {
        // get the shuffle that the caller is referring to
        MentalPokerShuffle storage shuffle = shuffles[_shuffleNum];

        // the aggregated public key that the player started with should be 
        // the aggregated public key that is stored in the smart contract.
        require(_keyAggregateProofData.old_aggk == shuffle.aggregatePublicKey);

        // get the caller's player object
        MentalPokerPlayer storage player = shuffle.players[msg.sender];

        // every player can submit a pk at most once
        require(player.pkSubmitted == false);

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
        player.pk = _keyAggregateProofData.pk;
        player.pkSubmitted = true;

        // update the aggregated public key on the smart contract.
        shuffle.aggregatePublicKey = _keyAggregateProofData.new_aggk;
        shuffle.keyAggregationCount++;

        // emit an event
        emit AggregateKeyUpdated(
            _shuffleNum,
            player.number,
            shuffle.aggregatePublicKey,
            keyAggregationCompleted(_shuffleNum)
        );

        return player.number;
    }

    /**
     * @dev
     */
    function encrypt(
        uint _shuffleNum,
        uint[2][52] memory input_tuples,
        uint[2][52] memory output_tuples,
        EncryptProofData memory _encryptProofData
    ) public isPlayer(msg.sender, _shuffleNum) {
        // get the shuffle that the caller is referring to
        MentalPokerShuffle storage shuffle = shuffles[_shuffleNum];

        // get the caller's player object
        MentalPokerPlayer storage player = shuffle.players[msg.sender];

        // every player can encrypt-shuffle at most once
        require(player.encryptedShuffled == false);

        // encryption is not allowed before the entire aggregate public key is calculated
        require(keyAggregationCompleted(_shuffleNum));

        // the caller should 1) encrypt-shuffle the latest version of the
        // encrypt-shuffled deck and 2) use the aggregate public key on the
        // smart contract.
        require(keccak256(abi.encode(input_tuples))
                == keccak256(abi.encode(shuffle.encryptedShuffledDeck)));
        require(_encryptProofData.aggk == shuffle.aggregatePublicKey);

        // TODO: check that the order of the flattening below is correct
        /* flatten the public zk data to pass in to verifyProof */
        uint[5] memory flattened;
        // copy the input hashes
        flattened[0] =  _encryptProofData.input_hashes[0];
        flattened[1] =  _encryptProofData.input_hashes[1];

        // copy the output hashes
        flattened[2] =  _encryptProofData.output_hashes[0];
        flattened[3] =  _encryptProofData.output_hashes[1];

        // copy the pk
        flattened[4] = _encryptProofData.aggk;

        // verify that the inputted deck is the shuffled and correctly-encrypted
        // version of the deck from the last round.
        require(encryptVerifier.verifyProof(
            _encryptProofData.a,
            _encryptProofData.b,
            _encryptProofData.c,
            flattened),
            "Invalid proof (encrypt)!"
        );

        // Important TODO: check that the tuples passed in to this function
        // actually hash to the hashes in the zkproof

        // update the deck on the smart contract.
        shuffle.encryptedShuffledDeck = output_tuples;

        // increment the counter
        shuffle.encryptShuffleCount++;
        player.encryptedShuffled = true;

        // signal the next player
        emit DeckEncryptedShuffled(
            _shuffleNum,
            player.number,
            encryptShuffleCompleted(_shuffleNum)
        );
    }

    /**
     * @dev  
     */
    function decrypt(
        uint _shuffleNum,
        uint256 _cardNum,
        DecryptProofData memory _decryptProofData
    ) public isPlayer(msg.sender, _shuffleNum) {
        // get the shuffle that the caller is referring to
        MentalPokerShuffle storage shuffle = shuffles[_shuffleNum];

        // get the caller's player object
        MentalPokerPlayer storage player = shuffle.players[msg.sender];

        // every player can encrypt-shuffle at most once
        require(player.cardDecrypted[_cardNum] == false);

        // decryption is not allowed before the deck is completely shuffled
        require(encryptShuffleCompleted(_shuffleNum));

        // the caller should 1) encrypt-shuffle the latest version of the
        // encrypt-shuffled card and 2) use the same secret key that it used
        // during the key aggregation process.
        require(keccak256(abi.encode(shuffle.encryptedShuffledDeck[_cardNum]))
                == keccak256(abi.encode(_decryptProofData.masked_card)));
        require(player.pk == _decryptProofData.pk);

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

        // update cardDecryptCounts mapping counter
        shuffle.cardDecryptCounts[_cardNum]++;
        player.cardDecrypted[_cardNum] = true;

        // update the card on the smart contract
        // the rest of the deck stays the same.
        uint[2] memory newCard = [_decryptProofData.masked_card[0], _decryptProofData.unmasked_card];
        shuffle.encryptedShuffledDeck[_cardNum] = newCard;

        emit CardDecrypted(
            _shuffleNum,
            _cardNum,
            player.number,
            finalDecryptLeft(_shuffleNum, _cardNum)
        );
    }
}
