pragma circom 2.0.0;

include "./algebra.circom";

template CardDecrypter(generator, num_bits){
    signal input masked_card[2]; // Tuple of field elements representing the masked card
    signal input sk; // Player secret key;
    signal output pk; // Player public key
    signal output unmasked_card; // Field element corresponding to a card OR an intermediate value

    // derive the pk from the sk
    component KeyExp = Pow(num_bits);
    KeyExp.exponent <== sk;
    KeyExp.base <== generator;
    pk <== KeyExp.out;

    // Apply partial decryption using the current player's secret key
    component CardExp = Pow(num_bits);
    CardExp.exponent <== sk;
    CardExp.base <== masked_card[0];
    unmasked_card <-- masked_card[1] / CardExp.out; // multiply masked_card[1] with the inverse of CardExp.out
    unmasked_card * CardExp.out === masked_card[1]; // this line is needed because having <== in the previous line introduces a non-linear constraint
}

component main {public [masked_card]} = CardDecrypter(3, 254);
