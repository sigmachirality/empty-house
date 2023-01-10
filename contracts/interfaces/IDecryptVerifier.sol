// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IDecryptVerifier {
    /// @return r  bool true if proof is valid
    function verifyProof(
            uint[2] memory a,
            uint[2][2] memory b,
            uint[2] memory c,
            uint[4] memory input
        ) external view returns (bool r);
}