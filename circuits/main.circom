pragma circom 2.0.0;

include "circomlib/bitify.circom";

// NOTE: first_mask is not strictly necessary when the cards are represented in 
// a prime field, as the identity element is 0, which can be represented as a value.
// However, we maintain the first_mask component signal for consistency with the
// implementation of this protocol over elliptic curves, where the identity element
// is the point at infinity, which cannot be represented as a value.

// Terminology: masking a deck means that it has been encrypted AND shuffled.

template DeckMasker(generator, num_cards, bit_length) {
    // declaration of signals
    signal input pk; // player aggregate key
    signal input first_mask; // during the first mask, set this flag to ignore m_a
    signal input permutation_matrix[num_cards][num_cards]; // permutation matrix to shuffle the deck
    signal input input_tuples[num_cards][2]; // array of card tuples
    signal input randomness[num_cards]; // player's private randomness vector (arbitrarily generated)
    signal output output_tuples[num_cards][2]; // shuffled array of masked cards tuples
    
    // Constrain the permutation matrix to be a valid permutation matrix
    component PermutationConstraint = PermutationConstraint(num_cards);
    for (var i = 0; i < num_cards; i++) {
        for (var j = 0; j < num_cards; j++) {
            PermutationConstraint.permutation_matrix[i][j] <== permutation_matrix[i][j];
        }
    }

    component DeckEncrypter[num_cards];
    for (var i = 0; i < num_cards; i++) {
        // Encryption inputs
        DeckEncrypter[i] = CardEncrypter(generator, bit_length);
        DeckEncrypter[i].pk <== pk;
        DeckEncrypter[i].first_mask <== first_mask;
        DeckEncrypter[i].unmasked_card[0] <== input_tuples[i][0];
        DeckEncrypter[i].unmasked_card[1] <== input_tuples[i][1];
        DeckEncrypter[i].random_factor <== randomness[i];
    }

    // signal accumulated_tuples[num_cards][2]; // temporary accumulator for the masked cards
    // for (var i = 0; i < num_cards; i++) {
    //     accumulated_tuples[i][0] <== DeckEncrypter[i].masked_card[0];
    //     accumulated_tuples[i][1] <== input_tuples[i][1] * DeckEncrypter[i].masked_card[1];
    // }


    component DeckShuffler = ScalarMatrixMul(num_cards, num_cards, 2);
    // Link input and output matrices 
    for (var i = 0; i < num_cards; i++) {
        for (var j = 0; j < num_cards; j++) {
            DeckShuffler.A[i][j] <== permutation_matrix[i][j];
        }
    }
    for (var n = 0; n < num_cards; n++) {
        DeckShuffler.B[n][0] <== DeckEncrypter[n].masked_card[0];
        DeckShuffler.B[n][1] <== DeckEncrypter[n].masked_card[1];
    }
    for (var m = 0; m < num_cards; m++) {
        output_tuples[m][0] <== DeckShuffler.AB[m][0];
        output_tuples[m][1] <== DeckShuffler.AB[m][1];
    }
}

template PermutationConstraint(n) {
    signal input permutation_matrix[n][n]; // permutation matrix to shuffle the deck
    
    // declaration of signals    
    component ElementBooleanConstraints[n][n];
    for (var i = 0; i < n; i++) {
        for (var j = 0; j < n; j++) {
            0 === permutation_matrix[i][j] * (permutation_matrix[i][j] - 1); // c is 0 or 1;
        }
    }

    // Check that each row sums to 1
    var accum = 0;
    for (var i = 0; i < n; i++) {
        accum = 0;
        for (var j = 0; j < n; j++) {
            accum += permutation_matrix[i][j];
        }
        1 === accum;
    }

    // Check that each col sums to 1
    for (var j = 0; j < n; j++) {
        accum = 0;
        for (var i = 0; i < n; i++) {
            accum += permutation_matrix[i][j];
        }
        1 === accum;
    }
}

// Masks a card or remasks field element with ElGamal encryption
// (G, Z, "1" -> G X G) | (G X G, Z, "0" -> G X G)
template CardEncrypter(generator, bit_length){  
    // declaration of signals
    signal input pk; // aggregate public key
    signal input first_mask; // during the first mask, set this flag to ignore m_a
    signal input unmasked_card[2]; // tuple of fields representing the card
    signal input random_factor; // random masking factor
    signal output masked_card[2]; // masked card

    // constraint inputs
    0 === first_mask * (first_mask - 1); // c is 0 or 1;

    // compute intermediate values.
    component exp1 = Pow(bit_length);
    exp1.exponent <== random_factor;
    exp1.base <== generator;
    component exp2 = Pow(bit_length);
    exp2.exponent <== random_factor;
    exp2.base <== pk ;
    
    // constrain outputs
    masked_card[0] <== unmasked_card[0] * exp1.out;
    assert(masked_card[0] > 0);
    masked_card[1] <== unmasked_card[1] * exp2.out;
}

template Pow(n) {
    signal input exponent;
    signal input base;
    signal output out;

    signal powers[n];
    signal accumulators[n];
    signal terms1[n];
    signal terms2[n];
    signal terms3[n];
    
    powers[0] <== base;
    for (var i = 1; i<n; i++) {
        powers[i] <== powers[i-1] * powers[i-1];
    }
    component num_to_bits = Num2Bits(n);
    num_to_bits.in <== exponent;
    terms1[0] <== num_to_bits.out[0] * powers[0];
    terms2[0] <== 1-num_to_bits.out[0];
    terms3[0] <== terms1[0] + terms2[0];
    accumulators[0] <== terms3[0];
    for(var i = 1; i<n; i++) {
        terms1[i] <== num_to_bits.out[i] * powers[i];
        terms2[i] <== 1-num_to_bits.out[i];
        terms3[i] <== terms1[i] + terms2[i];
        accumulators[i] <== terms3[i] * accumulators[i-1];
    }
    out <== accumulators[n-1];
}

// Multiplies Matrix A of size m x n by Matrix B of size n x p, producing Matrix AB of size m x p
template ScalarMatrixMul(m, n, p) {
    signal input A[m][n];
    signal input B[n][p];
    signal output AB[m][p];
    signal intermediates[m][p][n];
    for(var row = 0; row < m; row++) {
      for(var col = 0; col < p; col++) {
        var sum = 0;
        for(var i = 0; i < n; i++) {
          intermediates[row][col][i] <== A[row][i] * B[i][col];
          sum += intermediates[row][col][i];
        }
        AB[row][col] <== sum; 
      }
    }
}

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
