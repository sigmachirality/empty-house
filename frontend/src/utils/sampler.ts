import { BigNumber, utils } from "ethers";
import { ZqField } from "ffjavascript";

import { Card, Tuple, NUM_CARDS } from "../constants/cards";
import { R } from "../constants/field";

export const ZqZr = new ZqField(R);

// Sample a random card
export const sampleCard = () => {
  const card = Math.floor(Math.random() * 52) as Card;
  return card;
}

// Generate a random number from 2 to R in bigint
export const sampleFieldElement = () => {
  const randomHex = utils.randomBytes(8);
  const randomNum = BigNumber.from(randomHex).toBigInt();
  const maskingFactor = ZqZr.e(randomNum) satisfies bigint;
  return maskingFactor;
}

// Generate an array of random masking factors of length n
export const sampleMaskingFactors = () => {
  const factors = Array(NUM_CARDS).fill(0).map(sampleFieldElement);
  return factors as Tuple<bigint, typeof NUM_CARDS>;
}

// Generate a n by n identity matrix
export function generateIdentityMatrix() {
  return Array(NUM_CARDS).fill(0).map((_, i) => {
    const row = Array<number>(NUM_CARDS).fill(0);
    row[i] = 1;
    return row;
  }) as Tuple<Tuple<0 | 1, typeof NUM_CARDS>, typeof NUM_CARDS>;
}

// Sample a n by n permutation matrix
export function samplePermutationMatrix() {
  // Generate an identity matrix
  const matrix = generateIdentityMatrix();
  // Permute the matrix
  for (let j = NUM_CARDS - 1; j > 0;) {
    let i = Math.floor(Math.random() * j);
    [matrix[j], matrix[i]] = [matrix[i], matrix[j]];
    j--;
  }
  return matrix as Tuple<Tuple<0 | 1, typeof NUM_CARDS>, typeof NUM_CARDS>;
}
