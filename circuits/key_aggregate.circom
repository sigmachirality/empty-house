template GeneratePublicKey(generator, num_bits) {
    signal input sk;
    signal output pk;

    component KeyExp = Pow(num_bits);
    KeyExp.exponent <== sk;
    KeyExp.base <== generator;
    pk <== KeyExp.out;
}
