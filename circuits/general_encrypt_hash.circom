pragma circom 2.0.0;

include "./general_algebra.circom";
include "../node_modules/circomlib/circuits/pedersen.circom";

// TODO: first_mask is not strictly necessary when the cards are represented in 
// a prime field, as the identity element is 0, which can be represented as a value.
// However, we maintain the first_mask component signal for consistency with the
// implementation of this protocol over elliptic curves, where the identity element
// is the point at infinity, which cannot be represented as a value.

// Terminology: masking a deck means that it has been encrypted AND shuffled. 

template DeckMasker(generator, max_num_cards, bit_length) {
    // declaration of signals
    signal input num_cards;
    signal input agg_pk; // public aggregate key, with contributions from everyone in the group
    signal input permutation_matrix[max_num_cards][max_num_cards]; // permutation matrix to shuffle the deck
    signal input input_tuples_hashes[2];
    signal input input_tuples[max_num_cards][2]; // array of card tuples
    signal input randomness[max_num_cards]; // player's private randomness vector (arbitrarily generated)
    signal input output_tuples_hashes[2];
    signal output_tuples[max_num_cards][2]; // shuffled array of masked cards tuples
    
    // the input tuples must actually hash to input_tuples_hashes
    component input_hasher = Pedersen(2*max_num_cards);
    for (var i = 0; i < max_num_cards; i++) {
        input_hasher.in[2*i] <== input_tuples[i][0];
        input_hasher.in[2*i+1] <== input_tuples[i][1];
    }
    input_tuples_hashes[0] === input_hasher.out[0]; 
    input_tuples_hashes[1] === input_hasher.out[1];

    // Constrain the permutation matrix to be a valid permutation matrix
    component PermutationConstraint = PermutationConstraint(max_num_cards);
    PermutationConstraint.num_cards <== num_cards;
    for (var i = 0; i < max_num_cards; i++) {
        for (var j = 0; j < max_num_cards; j++) {
            PermutationConstraint.permutation_matrix[i][j] <== permutation_matrix[i][j];
        }
    }

    component DeckEncrypter[max_num_cards];
    for (var i = 0; i < max_num_cards; i++) {
        // Encryption inputs
        DeckEncrypter[i] = CardEncrypter(generator, bit_length);
        DeckEncrypter[i].agg_pk <== agg_pk;
        DeckEncrypter[i].unmasked_card[0] <== input_tuples[i][0];
        DeckEncrypter[i].unmasked_card[1] <== input_tuples[i][1];
        DeckEncrypter[i].random_factor <== randomness[i];
    }

    component DeckShuffler = ScalarMatrixMul(max_num_cards, max_num_cards, 2);
    // Link input and output matrices 
    for (var i = 0; i < max_num_cards; i++) {
        for (var j = 0; j < max_num_cards; j++) {
            DeckShuffler.A[i][j] <== permutation_matrix[i][j];
        }
    }
    for (var n = 0; n < max_num_cards; n++) {
        DeckShuffler.B[n][0] <== DeckEncrypter[n].masked_card[0];
        DeckShuffler.B[n][1] <== DeckEncrypter[n].masked_card[1];
    }
    for (var m = 0; m < max_num_cards; m++) {
        output_tuples[m][0] <== DeckShuffler.AB[m][0];
        output_tuples[m][1] <== DeckShuffler.AB[m][1];
    }

    // the output tuples must actually hash to output_tuples_hashes
    component output_hasher = Pedersen(2*max_num_cards);
    for (var i = 0; i < max_num_cards; i++) {
        output_hasher.in[2*i] <== output_tuples[i][0];
        output_hasher.in[2*i+1] <== output_tuples[i][1];
    }
    output_tuples_hashes[0] === output_hasher.out[0]; 
    output_tuples_hashes[1] === output_hasher.out[1]; 
}

// Masks a card or remasks field element with ElGamal encryption
// (G, Z, "1" -> G X G) | (G X G, Z, "0" -> G X G)
template CardEncrypter(generator, bit_length){  
    // declaration of signals
    signal input agg_pk; // aggregate public key
    signal input unmasked_card[2]; // tuple of fields representing the card
    signal input random_factor; // random masking factor
    signal output masked_card[2]; // masked card

    // compute intermediate values.
    component exp1 = Pow(bit_length);
    exp1.exponent <== random_factor;
    exp1.base <== generator;
    component exp2 = Pow(bit_length);
    exp2.exponent <== random_factor;
    exp2.base <== agg_pk;
    
    // constrain outputs
    masked_card[0] <== unmasked_card[0] * exp1.out;
    assert(masked_card[0] > 0);
    masked_card[1] <== unmasked_card[1] * exp2.out;
}

component main {public [input_tuples_hashes, agg_pk, output_tuples_hashes]} = DeckMasker(3, 52, 254);
