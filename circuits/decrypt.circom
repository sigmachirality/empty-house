pragma circom 2.0.0;

include "./algebra.circom";

template CardDecrypter(generator, num_bits){
    signal input masked_card[2]; // Tuple of field elements representing the masked card
    signal input pk; // Player public key
    signal input sk; // Player secret key;
    signal output unmasked_card; // Field element corresponding to a card OR an intermediate value

    // Verify that the pk was derived from the sk
    component KeyExp = Pow(num_bits);
    KeyExp.exponent <== sk;
    KeyExp.base <== generator;
    pk === KeyExp.out;

    // Apply partial decryption using current player's secret key
    component CardExp = Pow(num_bits);
    CardExp.exponent <== sk;
    CardExp.base <== masked_card[0];
    unmasked_card <-- masked_card[1] / CardExp.out;
}

component main = CardDecrypter(3, 254);
