import "./index.css"
import { useState } from "react";
import { ConnectButton } from '@rainbow-me/rainbowkit'
import { useAccount, useContract, useSigner } from 'wagmi'
import { useQuery } from '@tanstack/react-query'
import { BigNumber } from "ethers";
import z from 'zod';

import { MentalPoker } from "../../typechain-types/MentalPoker"
import MentalPokerABI from "../../artifacts/contracts/MentalPoker.sol/MentalPoker.json";
import KeyAggregate from "../../circuits/key_aggregate.wasm";
import AggregateZKey from "../../circuits/key_aggregate.zkey";
const { VITE_MENTAL_POKER_ADDRESS } = import.meta.env

import { groth16 } from "snarkjs";
import { exportSolidityCallDataGroth16 as exportSolidityCallData } from "./utils/snark-helpers";

import { Account } from './components'

// Form Schema
const secretKey = z.object({
  sk: z.coerce.number().int({ message: "Your secret key must be an integer" }),
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

  const { data: currentAggregateKey, refetch } = useQuery({
    queryKey: ['getCurrentAggregateKey'],
    queryFn: async () => MentalPoker.getCurrentAggregateKey(),
    initialData: BigNumber.from(1),
    refetchInterval: 1000,
  });
  
  const submitAggregateKey = async (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (MentalPoker === null) {
      setError("Unable to connect to contract. Are you on the right network?");
      return;
    }
    try {
      // Parse form inputs
      const inputFormData = new FormData(event.currentTarget);
      const inputData = Object.fromEntries(inputFormData.entries());
      const { sk } = secretKey.parse(inputData);
      // Fetch current aggregate key
      const oldAggregateKey = await MentalPoker.getCurrentAggregateKey();
      const oldAggregateBigInt = currentAggregateKey.toBigInt();

      // Generate witness and proof
      const { proof, publicSignals } = await groth16.fullProve({ sk, old_aggk: oldAggregateBigInt }, KeyAggregate, AggregateZKey);
      const { a, b, c, inputs } = await exportSolidityCallData({ proof, publicSignals });
      const newAggregateKey = inputs[0];

      // Update aggregate key with new value
      await MentalPoker.updateAggregateKey({
        a, b, c, 
        old_aggk: oldAggregateKey,
        new_aggk: newAggregateKey
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

  return (
    <>
      <h1 className="text-xl">absolutely mental poker</h1>

      {!isConnected && <ConnectButton />}
      {isConnected && <Account />}

      {isConnected && (
        <>
          <p>Current Aggregate Key: {currentAggregateKey.toString()}</p>
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
