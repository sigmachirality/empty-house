// SnarkJS has no official Typescript interface
declare module 'snarkjs';
declare module 'ffjavascript';
// Typescript lang server doesn't know how to handle these file types
declare module '*.wasm';
declare module '*.zkey';