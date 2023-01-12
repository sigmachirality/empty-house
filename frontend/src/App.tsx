import "./index.css"
import React, { useState } from "react";
import { ConnectButton } from '@rainbow-me/rainbowkit'
import { useAccount, useContract, useSigner } from 'wagmi'
import { useQuery } from '@tanstack/react-query'
import { BigNumber } from "ethers";
import z from 'zod';

import { MentalPoker } from "../../typechain-types/MentalPoker"
import MentalPokerABI from "../../artifacts/contracts/MentalPoker.sol/MentalPoker.json";

import ShuffleCards from "../../circuits/encrypt.wasm";
import ShuffleCardsZKey from "../../circuits/encrypt.zkey";
import CardDecrypt from "../../circuits/decrypt.wasm";
import CardDecryptZKey from "../../circuits/decrypt.zkey";
import KeyAggregate from "../../circuits/key_aggregate.wasm";
import KeyAggregateZKey from "../../circuits/key_aggregate.zkey";
const { VITE_MENTAL_POKER_ADDRESS } = import.meta.env

import { R } from "./constants/field";
import { ORDERED_CARDS } from "./constants/cards";
import { groth16 } from "snarkjs";
import { exportSolidityCallDataGroth16 as exportSolidityCallData } from "./utils/snark-helpers";

import { Account } from './components'
import { sampleFieldElement, sampleMaskingFactors, samplePermutationMatrix } from "./utils/sampler";


// Form Schema
const secretKey = z.object({
  sk: z.coerce.bigint().optional().refine((sk) => !sk || (sk >= 2 && sk < R), "Secret key invalid.")
})

// Main Component
export function App() {
  const [error, setError] = useState<string>()
  const { data: signer } = useSigner();
  const { isConnected } = useAccount()
  const MentalPoker = useContract({
    address: VITE_MENTAL_POKER_ADDRESS,
    abi: MentalPokerABI.abi,
    signerOrProvider: signer
  }) as MentalPoker;

  const { data: currentAggregateKey, refetch, isLoading } = useQuery({
    queryKey: ['getCurrentAggregateKey'],
    queryFn: async () => MentalPoker.getCurrentAggregateKey(),
    refetchInterval: 1000,
    refetchOnMount: true
  });
  
  const submitAggregateKey = async (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (MentalPoker === null || !currentAggregateKey) {
      setError("Unable to connect to contract. Are you on the right network?");
      return;
    }
    const inputFormData = new FormData(event.currentTarget);
    const inputData = Object.fromEntries(inputFormData.entries());
    try {
      await refetch();
      // Parse form inputs
      let { sk } = secretKey.parse(inputData);
      sk ||= sampleFieldElement();
      // Fetch current aggregate key
      const oldAggregateKey = await MentalPoker.getCurrentAggregateKey();
      const oldAggregateBigInt = currentAggregateKey.toBigInt();

      // Generate witness and proof
      const { proof, publicSignals } = await groth16.fullProve({ sk, old_aggk: oldAggregateBigInt }, KeyAggregate, KeyAggregateZKey);
      const { a, b, c, inputs } = await exportSolidityCallData({ proof, publicSignals });
      const [newAggregateKey, pk] = inputs;

      // Update aggregate key with new value
      await MentalPoker.updateAggregateKey({
        a, b, c, 
        old_aggk: oldAggregateKey,
        new_aggk: newAggregateKey,
        pk, // TODO: this is not correct lmao
       });
      refetch();
    } catch (error) {
      if (error instanceof z.ZodError) {
        setError(error.message);
      } else {
        setError(`Unsuccessful verification: ${error}`)
        console.error(error);
      }
    }
  }

  const shuffleDeck = async () => {
    // TODO: store this in state
    const sk = -1;
    const { proof, publicSignals } = await groth16.fullProve({
      pk: currentAggregateKey,
      permutation_matrix: samplePermutationMatrix(),
      input_tuples: ORDERED_CARDS,
      randomness: sampleMaskingFactors(),
    }, ShuffleCards, ShuffleCardsZKey);
    const { a, b, c, inputs } = await exportSolidityCallData({ proof, publicSignals });
  }

  return (
    <>
      <h1 className="text-xl">absolutely mental poker</h1>

      {!isConnected && <ConnectButton />}
      {isConnected && <Account />}

      {isConnected && (
        <>
          <p>Current Aggregate Key: {!isLoading ? currentAggregateKey?.toString?.() : "loading..."}</p>
          <form onSubmit={submitAggregateKey}>
            <input name="sk" type="number" placeholder="Enter a secret key" />
            <button type="submit">Submit</button>
          </form>
          {error && <p className="text-red-500">{error}</p>}
        </>
      )}
    </>
  )
}
