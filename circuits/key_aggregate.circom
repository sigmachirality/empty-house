pragma circom 2.0.0;

include "./algebra.circom";

template GeneratePublicKey(generator, num_bits) {
    signal input sk;
    signal output pk;

    component KeyExp = Pow(num_bits);
    KeyExp.exponent <== sk;
    KeyExp.base <== generator;
    pk <== KeyExp.out;
}

component main = GeneratePublicKey(3, 254);