import "./index.css"
import { useState } from "react";
import { ConnectButton } from '@rainbow-me/rainbowkit'
import { useAccount, useContract } from 'wagmi'
import { BigNumber } from "ethers";
import z from 'zod';

import { VerifierArtifact } from '../constants/artifacts';
import KeyAggregate from "../../circuits/key_aggregate.wasm";
import AggregateZKey from "../../circuits/key_aggregate.zkey";

import { groth16 } from "snarkjs";
import { Account } from './components'

// Form Schema
const secretKey = z.object({
  sk: z.coerce.number().int({ message: "Your secret key must be an integer" }),
})

// Main Component
export function App() {
  const [error, setError] = useState<string>()

  const { isConnected } = useAccount()
  const aggregateKeyGenerator = useContract({
    address: import.meta.env.AGGREGATE_KEY_CONTRACT_ADDRESS,
    abi: VerifierArtifact.abi,
  });

  const handleSubmit = async (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (aggregateKeyGenerator === null) {
      setError("Unable to connect to contract. Are you on the right network?");
      return;
    }

    const inputFormData = new FormData(event.currentTarget);
    // convert form data to object
    const inputData = Object.fromEntries(inputFormData.entries());
    try {
      const { sk } = secretKey.parse(inputData);
      const { proof, publicSignals } = await groth16.fullProve({ sk }, KeyAggregate, AggregateZKey);

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
      const input: readonly BigNumber[] = argv.slice(8);

      // TODO: Extract this into a function with a nicer interface
      const result = await aggregateKeyGenerator?.verifyProof(a, b, c, input as [BigNumber]);
      console.log(result);
    } catch (error) {
      if (error instanceof z.ZodError) {
        setError(error.message);
      } else {
        setError(`Insuccessful verification: ${error}`)
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
          <form onSubmit={handleSubmit}>
            <input name="sk" type="number" placeholder="Enter a secret key" />
            <button type="submit">Submit</button>
          </form>
          // Error handling
          {error && <p className="text-red-500">{error}</p>}
        </>
      )}
    </>
  )
}
