pragma circom 2.0.0;

include "circomlib/bitify.circom";


template ExampleShuffleMaskUnmasker(){
    var NUM_CARDS = 6;
    var BIT_LENGTH = 254;
    var G = 3;
    
    // example shuffle encrypt
    // player 1
    signal input card_deck[NUM_CARDS][2];
    signal input public_key;
    signal input secret_key;

    signal input permutation_matrix[NUM_CARDS][NUM_CARDS];
    signal input randomness[NUM_CARDS];

    signal output shuffled_cards[NUM_CARDS][2];

    // player 2
    signal input public_key2;
    signal input secret_key2;
    signal input permutation_matrix2[NUM_CARDS][NUM_CARDS];
    signal input randomness2[NUM_CARDS];

    component deck_shuffle = DeckMasker(G, NUM_CARDS, BIT_LENGTH);
    deck_shuffle.pk <== public_key * public_key2;
    deck_shuffle.first_mask <== 1;
    for (var i = 0; i < NUM_CARDS; i++) {
        for(var j = 0; j < NUM_CARDS; j++) {
            deck_shuffle.permutation_matrix[i][j] <== permutation_matrix[i][j];
        }
    }
    for (var i = 0; i < NUM_CARDS; i++){
        deck_shuffle.input_tuples[i][0] <== card_deck[i][0]; // Should be zero
        deck_shuffle.input_tuples[i][1] <== card_deck[i][1];
    }
    for (var i = 0; i < NUM_CARDS; i++){
        deck_shuffle.randomness[i] <== randomness[i];
    }

    for (var i = 0; i < NUM_CARDS; i++){
        shuffled_cards[i][0] <== deck_shuffle.output_tuples[i][0];
        shuffled_cards[i][1] <== deck_shuffle.output_tuples[i][1];
    }

    // second shuffle
    component deck_shuffle2 = DeckMasker(G, NUM_CARDS, BIT_LENGTH);
    deck_shuffle2.pk <== public_key2 * public_key;
    deck_shuffle2.first_mask <== 1;
    for (var i = 0; i < NUM_CARDS; i++) {
        for(var j = 0; j < NUM_CARDS; j++) {
            deck_shuffle2.permutation_matrix[i][j] <== permutation_matrix2[i][j];
        }
    }
    for (var i = 0; i < NUM_CARDS; i++){
        deck_shuffle2.input_tuples[i][0] <== shuffled_cards[i][0]; // Should be zero
        deck_shuffle2.input_tuples[i][1] <== shuffled_cards[i][1];
    }
    for (var i = 0; i < NUM_CARDS; i++){
        deck_shuffle2.randomness[i] <== randomness2[i];
    }

    signal output shuffled_cards2[NUM_CARDS][2];

    for (var i = 0; i < NUM_CARDS; i++){
        shuffled_cards2[i][0] <== deck_shuffle2.output_tuples[i][0];
        shuffled_cards2[i][1] <== deck_shuffle2.output_tuples[i][1];
    }

    signal output intermediate_decrypted_card;

    // example decryptCard
    component card_decrypt = CardDecrypter(G, BIT_LENGTH);
    // first intermediate decryption
    card_decrypt.masked_card[0] <== shuffled_cards2[0][0];  
    card_decrypt.masked_card[1] <== shuffled_cards2[0][1];
    card_decrypt.pk <== public_key;
    card_decrypt.sk <== secret_key;
    intermediate_decrypted_card <== card_decrypt.unmasked_card;

    signal output revealed_card;
    component card_decrypt2 = CardDecrypter(G, BIT_LENGTH);
    // final decryption
    card_decrypt2.masked_card[0] <== shuffled_cards2[0][0];  
    card_decrypt2.masked_card[1] <== intermediate_decrypted_card;
    card_decrypt2.pk <== public_key2;
    card_decrypt2.sk <== secret_key2;
    revealed_card <== card_decrypt2.unmasked_card;
}


component main { public [
    card_deck,
    public_key,
    secret_key
]} = ExampleShuffleMaskUnmasker();

/* INPUT = {
    "card_deck": [["1", "3"], ["1", "9"], ["1", "27"], ["1", "27"], ["1", "81"], ["1", "5"]],
    "randomness": ["10", "4", "5", "6", "7", "9"],
    "permutation_matrix" : [["1", "0", "0", "0", "0", "0"], ["0", "1", "0", "0", "0", "0"], ["0", "0", "1", "0", "0", "0"], ["0", "0", "0", "1", "0", "0"], ["0", "0", "0", "0", "1", "0"], ["0", "0", "0", "0", "0", "1"]],
    "public_key": "2187",
    "secret_key": "7",
    "public_key2": "243",
    "secret_key2": "5",
    "randomness2": ["1", "2", "9", "4", "2", "1"],
    "permutation_matrix2": [["0", "0", "1", "0", "0", "0"], ["0", "1", "0", "0", "0", "0"], ["1", "0", "0", "0", "0", "0"], ["0", "0", "0", "1", "0", "0"], ["0", "0", "0", "0", "1", "0"], ["0", "0", "0", "0", "0", "1"]]
} */
