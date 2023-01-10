pragma circom 2.0.0;
import "../node_modules/circomlib/circuits/babyjub.circom";

template EncryptCard(){  
    // Declaration of signals.  

    // player pk
    signal input pk;
    // input card tuple - ((m_a_x, m_a_y), (m_b_x, m_b_y)))
    signal input m_a_x; signal input m_a_y;
    signal input m_b_x; signal input m_b_y;
    // random masking factor
    signal input r;
    // during the first mask, set this flag to ignore m_a
    signal input first;

    // masked card tuple - ((c_a_x, c_a_y), (c_b_x, c_b_y)))
    signal output c_a_x; signal output c_a_y;
    signal output c_b_y; signal output c_b_y;


    // Witness generation.

    // c_a <-- ((1 - first) * m_a) + r * BASEB; // TODO: Find BASEB const in Circom
    // c_b <-- m_b + r * BASEB;

    // Constraints.  
    0 === first * (first - 1) // c is 0 or 1

}

template ShuffleCards(num_cards){

}

template DecryptCard(){

}

template ExampleRound(){
    component encryptedCard = EncryptCard();
    component encryptedCard = EncryptCard();
    
}

component main = ExampleRound();