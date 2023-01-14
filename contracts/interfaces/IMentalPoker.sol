pragma solidity >0.6.0 <0.9.0;

interface IMentalPoker {
    function newShuffle(
        address[] memory playerAddresses
    ) external returns (uint); 
}