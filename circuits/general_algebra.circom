pragma circom 2.0.0;

include "../node_modules/circomlib/circuits/bitify.circom";
include "../node_modules/circomlib/circuits/comparators.circom";
// TODO: investigate circom path import aliasing

template Pow(n) {
    signal input base;
    signal input exponent;
    signal output out;

    component n2b = Num2Bits(n);
    n2b.in <== exponent;
    signal pow[n];
    signal inter[n];
    signal temp[n];

    pow[0] <== base;
    temp[0] <== pow[0] * n2b.out[0] + (1 - n2b.out[0]);
    inter[0] <== temp[0];

    for (var i = 1; i < n; i++) {
        pow[i] <== pow[i-1] * pow[i-1];
        temp[i] <== pow[i] * n2b.out[i] + (1 - n2b.out[i]);
        inter[i] <==  inter[i-1] * temp[i];
    }

    out <== inter[n-1];
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

// https://stackoverflow.com/questions/70967265/how-to-write-a-constraint-that-depends-on-a-condition-in-circom
template PermutationConstraint(n) {
    signal input num_cards;
    signal input permutation_matrix[n][n]; // permutation matrix to shuffle the deck
    
    // declaration of signals    
    component ElementBooleanConstraints[n][n];
    for (var i = 0; i < n; i++) {
        for (var j = 0; j < n; j++) {
            0 === permutation_matrix[i][j] * (permutation_matrix[i][j] - 1); // c is 0 or 1;
        }
    }

    // Check that each row sums to 1 in the submatrix
    component is_within_submatrix_row[n][n];
    component row_outside_submatrix[n];
    signal row_sums[n][n];
    signal final_row_sum[n];
    for (var i = 0; i < n; i++) {
        // the matrix size is at least 1, so it is safe to include the top left corner in every case
        row_sums[i][0] <== permutation_matrix[i][0];
        
        // sum up the values in the row but don't count the ones outside the submatrix
        for (var j = 1; j < n; j++) {
            is_within_submatrix_row[i][j] = LessThan(252);
            is_within_submatrix_row[i][j].in[0] <== j;
            is_within_submatrix_row[i][j].in[1] <== num_cards;
            row_sums[i][j] <== row_sums[i][j-1] + permutation_matrix[i][j] * is_within_submatrix_row[i][j].out;
        }

        // mark the row as valid if it is outside the submatrix
        row_outside_submatrix[i] = GreaterEqThan(252);
        row_outside_submatrix[i].in[0] <== i;
        row_outside_submatrix[i].in[1] <== num_cards;
        final_row_sum[i] <-- 1 == row_outside_submatrix[i].out ? 1 : row_sums[i][n-1];

        1 === final_row_sum[i];
    }

    // Check that each col sums to 1 in the submatrix
    component is_within_submatrix_col[n][n];
    component col_outside_submatrix[n];
    signal col_sums[n][n];
    signal final_col_sum[n];
    for (var j = 0; j < n; j++) {
        // the matrix size is at least 1, so it is safe to include the top left corner in every case
        col_sums[0][j] <== permutation_matrix[0][j];

        // sum up the values in the column but don't count the ones outside the submatrix
        for (var i = 1; i < n; i++) {
            is_within_submatrix_col[i][j] = LessThan(252);
            is_within_submatrix_col[i][j].in[0] <== i;
            is_within_submatrix_col[i][j].in[1] <== num_cards;
            col_sums[i][j] <== col_sums[i-1][j] + permutation_matrix[i][j] * is_within_submatrix_col[i][j].out;
        }

        // mark the column as valid if it is outside the submatrix
        col_outside_submatrix[j] = GreaterEqThan(252);
        col_outside_submatrix[j].in[0] <== j;
        col_outside_submatrix[j].in[1] <== num_cards;
        final_col_sum[j] <-- 1 == col_outside_submatrix[j].out ? 1 : col_sums[n-1][j];

        1 === final_col_sum[j];
    }
}
