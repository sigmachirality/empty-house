import "./index.css"
import { useState } from "react";
import { ConnectButton } from '@rainbow-me/rainbowkit'
import { useAccount, useContract, useSigner } from 'wagmi'
import { BigNumber } from "ethers";
import z from 'zod';

import { MentalPokerArtifact } from '../constants/artifacts';
import KeyAggregate from "../../circuits/key_aggregate.wasm";
import AggregateZKey from "../../circuits/key_aggregate.zkey";

import { groth16 } from "snarkjs";
import { Account } from './components'

const MENTAL_POKER_CONTRACT_ADDRESS = "0xa85233C63b9Ee964Add6F2cffe00Fd84eb32338f" as const;

// Form Schema
const secretKey = z.object({
  sk: z.coerce.number().int({ message: "Your secret key must be an integer" }),
})

// Main Component
export function App() {
  const [error, setError] = useState<string>()
  const [currentAggregateKey, setCurrentAggregateKey] = useState<BigNumber>(BigNumber.from(1));

  const { data: signer } = useSigner();
  const { isConnected } = useAccount()
  const MentalPoker = useContract({
    address: MENTAL_POKER_CONTRACT_ADDRESS,
    abi: MentalPokerArtifact.abi,
    signerOrProvider: signer
  });
  
  const handleSubmit = async (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (MentalPoker === null) {
      setError("Unable to connect to contract. Are you on the right network?");
      return;
    }

    const inputFormData = new FormData(event.currentTarget);
    // convert form data to object
    const inputData = Object.fromEntries(inputFormData.entries());
    try {
      const { sk } = secretKey.parse(inputData);
      const currentAggregateKey = await MentalPoker.getCurrentAggregateKey();
      const old_aggk = currentAggregateKey.toBigInt();
      const { proof, publicSignals } = await groth16.fullProve({ sk, old_aggk }, KeyAggregate, AggregateZKey);

      // Extract this function:
      const calldata = await groth16.exportSolidityCallData(proof, publicSignals);
      // TODO: investigate exactly what this function is doing
      const argv: readonly BigNumber[] = calldata
        .replace(/["[\]\s]/g, "")
        .split(",")
        .map((x: string) => BigNumber.from(x));
    
      const a = [argv[0], argv[1]] as const;
      const b = [
        [argv[2], argv[3]],
        [argv[4], argv[5]],
      ] as const;
      const c = [argv[6], argv[7]] as const;
      const new_aggk = argv[8];

      // TODO: Extract this into a function with a nicer interface
      const result = await MentalPoker.updateAggregateKey({a, b, c, old_aggk: currentAggregateKey, new_aggk});
      setCurrentAggregateKey(new_aggk);
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
          <form onSubmit={handleSubmit}>
            <input name="sk" type="number" placeholder="Enter a secret key" />
            <button type="submit">Submit</button>
          </form>
          {error && <p className="text-red-500">{error}</p>}
        </>
      )}
    </>
  )
}
