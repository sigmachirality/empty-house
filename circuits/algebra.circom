pragma circom 2.0.0;

include "circomlib/bitify.circom";

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
