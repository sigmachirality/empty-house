pragma solidity >0.6.0 <0.9.0;

import "./interfaces/IMentalPoker.sol";

contract GameManager{
    // Game state
    enum SimplePokerGameState {
        BLIND_SET,
        PLAYERS_JOINED,
        GAMEPLAY_STARTED,
        WINNER_DETERMINED
    }

    // SimplePokerGame struct
    struct SimplePokerGame{
        uint256 gameLobbyNumber;
        uint256 numPlayers;
        mapping(uint256 => address payable) players;
        mapping(address => uint256) playerBets;
        mapping(address => uint256) playerCards;
        uint256 numCardsSubmitted;
        
        SimplePokerGameState state;

        // uint256 round;
        bool playerRaised;
    }

    // current game number
    uint globalGameCounter;

    // current game inovocations
    mapping (uint256 => SimplePokerGame) globalGameInvocations;

    // events to emit state
    event GameCreated(uint256 gameLobbyNumber, uint256 blind, uint256 numPlayers);
    event GameJoined(uint256 gameLobbyNumber, address payable player);
    event GameStarted(uint256 gameLobbyNumber);//, uint shuffleIndex);
    event GameRaised(uint256 gameLobbyNumber, uint256 amount);
    event GameMatched(uint256 gameLobbyNumber, uint256 amount);
    event GameCompleted(uint256 gameLobbyNumber, uint256 payout, address payable from, address payable to);
    
    // Function to receive Ether. msg.data must be empty
    receive() external payable {}

    // Fallback function is called when msg.data is not empty
    fallback() external payable {}

    function getBalance() public view returns (uint) {
        return address(this).balance;
    }

    constructor (address _mentalPoker) public {
        globalGameCounter = 0;
        IMentalPoker(_mentalPoker);
    }
    
    function getGameState(uint gameLobbyNumber) public view returns (SimplePokerGameState){        
        return globalGameInvocations[gameLobbyNumber].state;
    }

    function getCurrentGlobalGameCounter() public view returns (uint256){
        return globalGameCounter;
    }

    function getBetSize(uint256 gameLobbyNumber, address player) public view returns (uint256){
        return globalGameInvocations[gameLobbyNumber].playerBets[player];
    }

    // view function to see if a player has raised in a given lobby
    function hasPlayerRaised(uint256 gameLobbyNumber) public view returns (bool) {
        return globalGameInvocations[gameLobbyNumber].playerRaised;
    }

    // function to create a new game and set the blind
    // send money when calling
    function createNewGame() public payable {
        // require that the blind is greater than 0
        require(msg.value > 0, "Blind must be greater than 0");
        // create a new game
        SimplePokerGame storage newPokerGame = globalGameInvocations[globalGameCounter];
        newPokerGame.gameLobbyNumber = globalGameCounter;
        newPokerGame.numCardsSubmitted = 0;
        newPokerGame.numPlayers = 1;
        newPokerGame.state = SimplePokerGameState.BLIND_SET;
        newPokerGame.playerRaised = false;
        // globalGameInvocations[globalGameCounter] = SimplePokerGame({
        //     gameLobbyNumber: globalGameCounter, 
        //     numCardsSubmitted: 0,
        //     numPlayers: 1,
        //     state: SimplePokerGameState.BLIND_SET,
        //     playerRaised: false
        // });

        // add the player to the game
        globalGameInvocations[globalGameCounter].players[0] = payable(msg.sender);

        // set player bet
        globalGameInvocations[globalGameCounter].playerBets[globalGameInvocations[globalGameCounter].players[0]] = msg.value;
        
        // emit an event to signal the game has been created
        emit GameCreated(globalGameCounter, globalGameInvocations[globalGameCounter].playerBets[globalGameInvocations[globalGameCounter].players[0]], globalGameInvocations[globalGameCounter].numPlayers);

        // increment the game counter
        globalGameCounter++;
    }

    // function to join a game given a game number, and a sending address
    // currently supports 2 players
    // send money when calling
    function joinGame(uint256 gameLobbyNumber) public payable {
        require(globalGameInvocations[gameLobbyNumber].numPlayers < 3, "Game is full");
        
        globalGameInvocations[gameLobbyNumber].players[globalGameInvocations[gameLobbyNumber].numPlayers] = payable(msg.sender);
        globalGameInvocations[gameLobbyNumber].numPlayers++;
        globalGameInvocations[gameLobbyNumber].state = SimplePokerGameState.PLAYERS_JOINED;
        globalGameInvocations[globalGameCounter].playerBets[msg.sender] = globalGameInvocations[gameLobbyNumber].playerBets[globalGameInvocations[gameLobbyNumber].players[0]];
        
        emit GameJoined(gameLobbyNumber, payable(msg.sender));
    }

    // function to start a game
    // use newShuffle here
    function startGame(uint256 gameLobbyNumber) public {
        require(globalGameInvocations[gameLobbyNumber].state == SimplePokerGameState.PLAYERS_JOINED, "Game is not in the blind set state");
        require(globalGameInvocations[gameLobbyNumber].numPlayers >= 2, "Minimum of two players needed to start the game");
        
        // call new shuffle
        address[] memory shuffleAddresses = new address[](globalGameInvocations[gameLobbyNumber].numPlayers);
        for(uint i = 0; i < globalGameInvocations[gameLobbyNumber].numPlayers; i++){
            shuffleAddresses[i] = address(globalGameInvocations[gameLobbyNumber].players[i]);
        }

        // uint shuffleInvocationIndex = globalGameInvocations[globalGameCounter].mp.newShuffle(shuffleAddresses);
        globalGameInvocations[gameLobbyNumber].state = SimplePokerGameState.GAMEPLAY_STARTED;
        emit GameStarted(gameLobbyNumber);
        //, shuffleInvocationIndex);
    }

    // function for player to raise the bet
    // send money when calling
    function raise(uint256 gameLobbyNumber) public payable {
        require(globalGameInvocations[gameLobbyNumber].state == SimplePokerGameState.GAMEPLAY_STARTED, "Game is not in the cards submitted state");
        if(!globalGameInvocations[gameLobbyNumber].playerRaised){
            globalGameInvocations[gameLobbyNumber].playerRaised = true;
            globalGameInvocations[gameLobbyNumber].playerBets[msg.sender] += msg.value;
            emit GameRaised(gameLobbyNumber, msg.value);
        } 
        // both players have raised
        globalGameInvocations[gameLobbyNumber].playerBets[msg.sender] += msg.value;
        emit GameMatched(gameLobbyNumber, msg.value);
    }

    // function for player to fold and take the loss
    // asssumes two players
    function fold(uint256 gameLobbyNumber) public {
        require(globalGameInvocations[gameLobbyNumber].state == SimplePokerGameState.GAMEPLAY_STARTED, "Game is not in the cards submitted state");
        require(globalGameInvocations[gameLobbyNumber].numPlayers >= 2, "Minimum of two players needed to start the game");

        address payable nonFoldingPlayer;
        if(globalGameInvocations[gameLobbyNumber].players[0] == msg.sender){
            nonFoldingPlayer = globalGameInvocations[gameLobbyNumber].players[1];
        } else {
            nonFoldingPlayer = globalGameInvocations[gameLobbyNumber].players[0];
        }

        // send eth to nonFoldingPlayer from foldingPlayer
        uint256 totalPayout = globalGameInvocations[gameLobbyNumber].playerBets[nonFoldingPlayer] + globalGameInvocations[gameLobbyNumber].playerBets[msg.sender];
        bool sent = nonFoldingPlayer.send(totalPayout);
        require(sent, "Failed to send Ether");
        
        globalGameInvocations[gameLobbyNumber].state = SimplePokerGameState.WINNER_DETERMINED;
        emit GameCompleted(gameLobbyNumber, totalPayout, payable(msg.sender), nonFoldingPlayer);
    }
    
    // final compare updates
    function revealPlayerCard(uint256 gameLobbyNumber, uint256 card) public {
        require(globalGameInvocations[gameLobbyNumber].state == SimplePokerGameState.GAMEPLAY_STARTED, "Game is not in the cards submitted state");
        require(globalGameInvocations[gameLobbyNumber].numPlayers >= 2, "Minimum of two players needed to start the game");
        require(globalGameInvocations[gameLobbyNumber].players[0] == msg.sender || globalGameInvocations[gameLobbyNumber].players[1] == msg.sender, "Player is not in the game");
        require(globalGameInvocations[gameLobbyNumber].playerCards[msg.sender] == 0, "Player has already submitted a card");
        
        globalGameInvocations[gameLobbyNumber].playerCards[msg.sender] = card;
        globalGameInvocations[gameLobbyNumber].numCardsSubmitted++;
        if(globalGameInvocations[gameLobbyNumber].numCardsSubmitted == globalGameInvocations[gameLobbyNumber].numPlayers){
            // check who won
            if(globalGameInvocations[gameLobbyNumber].playerCards[globalGameInvocations[gameLobbyNumber].players[0]] > globalGameInvocations[gameLobbyNumber].playerCards[globalGameInvocations[gameLobbyNumber].players[1]]){
                address payable winner = globalGameInvocations[gameLobbyNumber].players[0];
                address payable loser = globalGameInvocations[gameLobbyNumber].players[1];
                uint256 totalPayout = globalGameInvocations[gameLobbyNumber].playerBets[winner] + globalGameInvocations[gameLobbyNumber].playerBets[loser];
                bool sent = winner.send(totalPayout);
                require(sent, "Failed to send Ether");
                globalGameInvocations[gameLobbyNumber].state = SimplePokerGameState.WINNER_DETERMINED;
                emit GameCompleted(gameLobbyNumber, totalPayout, loser, winner);
            } else if (globalGameInvocations[gameLobbyNumber].playerCards[globalGameInvocations[gameLobbyNumber].players[0]] == globalGameInvocations[gameLobbyNumber].playerCards[globalGameInvocations[gameLobbyNumber].players[1]]) {
                // refund
                address payable p1 = globalGameInvocations[gameLobbyNumber].players[0];
                address payable p2 = globalGameInvocations[gameLobbyNumber].players[1];
                uint256 totalPayoutP1 = globalGameInvocations[gameLobbyNumber].playerBets[p1];
                uint256 totalPayoutP2 = globalGameInvocations[gameLobbyNumber].playerBets[p2];
                bool sent = p1.send(totalPayoutP1);
                require(sent, "Failed to send Ether");
                bool sent2 = p2.send(totalPayoutP2);
                require(sent2, "Failed to send Ether");
                globalGameInvocations[gameLobbyNumber].state = SimplePokerGameState.WINNER_DETERMINED;
                emit GameCompleted(gameLobbyNumber, totalPayoutP1 + totalPayoutP2, p1, p2);
            } else {
                address payable winner = globalGameInvocations[gameLobbyNumber].players[1];
                address payable loser = globalGameInvocations[gameLobbyNumber].players[0];
                uint256 totalPayout = globalGameInvocations[gameLobbyNumber].playerBets[winner] + globalGameInvocations[gameLobbyNumber].playerBets[loser];
                bool sent = winner.send(totalPayout);
                require(sent, "Failed to send Ether");
                globalGameInvocations[gameLobbyNumber].state = SimplePokerGameState.WINNER_DETERMINED;
                emit GameCompleted(gameLobbyNumber, totalPayout, loser, winner);
            }
        }
    }
}