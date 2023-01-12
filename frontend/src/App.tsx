import "./index.css";
import React, { useEffect, useState } from "react";
import { ConnectButton } from "@rainbow-me/rainbowkit";
import { useAccount, useContract, useSigner } from "wagmi";
import { useQuery } from "@tanstack/react-query";
import z from "zod";

import { MentalPoker } from "../../typechain-types/MentalPoker";
import MentalPokerABI from "../../artifacts/contracts/MentalPoker.sol/MentalPoker.json";

import ShuffleCards from "../../circuits/encrypt.wasm";
import ShuffleCardsZKey from "../../circuits/encrypt.zkey";
import DealCard from "../../circuits/decrypt.wasm";
import DealCardZKey from "../../circuits/decrypt.zkey";
import KeyAggregate from "../../circuits/key_aggregate.wasm";
import KeyAggregateZKey from "../../circuits/key_aggregate.zkey";
const { VITE_MENTAL_POKER_ADDRESS } = import.meta.env;

import { R } from "./constants/field";
import { coerceToBigInt, marshallCardArray } from "./constants/cards";
import { groth16 } from "snarkjs";
import { exportSolidityCallDataGroth16 as exportSolidityCallData } from "./utils/snark-helpers";

import { Account } from "./components";
import {
  sampleFieldElement,
  sampleMaskingFactors,
  generateIdentityMatrix
} from "./utils/sampler";
import { BigNumber } from "ethers";

// Form Schema
const secretKey = z.object({
  sk: z.coerce
    .bigint()
    .refine((sk) => !sk || (sk >= 2 && sk < R), "Secret key invalid."),
});

// Main Component
export function App() {
  const [error, setError] = useState<string>();
  const [sk, setSk] = useState<string>(sampleFieldElement().toString());
  // const [playerPk, setPlayerPk] = useState<BigNumber>();

  const { data: signer } = useSigner();
  const { isConnected } = useAccount();
  const MentalPoker = useContract({
    address: VITE_MENTAL_POKER_ADDRESS,
    abi: MentalPokerABI.abi,
    signerOrProvider: signer,
  }) as MentalPoker;

  const {
    data,
    refetch,
    isLoading,
  } = useQuery({
    queryKey: ["getCurrentAggregateKey"],
    queryFn: async () => {
      return await Promise.all([
        MentalPoker.getCurrentAggregateKey(),
        MentalPoker.getDeck(),
      ]);
    },
    refetchInterval: 1000,
    refetchOnMount: true,
  });
  const [currentAggregateKey, deck] = data ?? [];

  useEffect(() => {
    if (!sk) setSk(sampleFieldElement().toString());
  }, [sk]);

  const submitAggregateKey = async (
    event: React.FormEvent<HTMLFormElement>
  ) => {
    event.preventDefault();
    if (MentalPoker === null || !currentAggregateKey) {
      setError("Unable to connect to contract. Are you on the right network?");
      return;
    }
    setError(undefined);
    const inputFormData = new FormData(event.currentTarget);
    const inputData = Object.fromEntries(inputFormData.entries());
    try {
      await refetch();
      // Parse form inputs
      let { sk } = secretKey.parse(inputData);
      sk ||= sampleFieldElement();
      console.log(sk);
      // Fetch current aggregate key
      const oldAggregateKey = await MentalPoker.getCurrentAggregateKey();
      const oldAggregateBigInt = currentAggregateKey.toBigInt();

      // Generate witness and proof
      const { proof, publicSignals } = await groth16.fullProve(
        { sk, old_aggk: oldAggregateBigInt },
        KeyAggregate,
        KeyAggregateZKey
      );
      const { a, b, c, inputs } = await exportSolidityCallData({
        proof,
        publicSignals,
      });
      const [newAggregateKey, pk] = inputs;

      // Update aggregate key with new value
      await MentalPoker.updateAggregateKey({
        a, b, c,
        old_aggk: oldAggregateKey,
        new_aggk: newAggregateKey,
        pk,
      });
      refetch();
      // setPlayerPk(pk);
    } catch (error) {
      if (error instanceof z.ZodError) {
        setError(error.message);
      } else {
        setError(`Unsuccessful verification: ${error}`);
        console.error(error);
      }
    }
  };

  const shuffleDeck = async () => {
    if (MentalPoker === null || !deck) {
      setError("Unable to connect to contract. Are you on the right network?");
      return;
    }
    if (MentalPoker === null || !deck || !currentAggregateKey) {
      setError("Unable to connect to contract. Are you on the right network?");
      return;
    }
    const { proof, publicSignals } = await groth16.fullProve(
      {
        pk: currentAggregateKey.toBigInt(),
        permutation_matrix: generateIdentityMatrix(),
        input_tuples: deck.map(tuple => tuple.map(coerceToBigInt)),
        randomness: sampleMaskingFactors(),
      },
      ShuffleCards,
      ShuffleCardsZKey
    );
    const { a, b, c, inputs } = await exportSolidityCallData({ proof, publicSignals });
    const maskedCards = marshallCardArray(inputs.slice(0, 12));

    await MentalPoker.encrypt({
      a, b, c,
      input_tuples: deck,
      aggk: currentAggregateKey,
      output_tuples: maskedCards,
    });
    refetch();
  };

  const dealCard = async () => {
    if (MentalPoker === null || !deck) {
      // TODO: more descriptive errors (maybe Zod?)
      setError("Unable to connect to contract. Are you on the right network?");
      return;
    }
    const { proof, publicSignals } = await groth16.fullProve(
      {
        masked_card: deck[0].map(coerceToBigInt),
        sk: BigInt(sk),
      },
      DealCard,
      DealCardZKey
    );
    const { a, b, c, inputs } = await exportSolidityCallData({ proof, publicSignals });
    const [pk, unmaskedCard] = inputs;
    console.log(inputs.map(coerceToBigInt))

    // Todo: change card number based on player number
    await MentalPoker.decrypt(0,
      {
        a, b, c,
        masked_card: deck[0],
        unmasked_card: unmaskedCard,
        pk
      });
    console.log("UNMASKED CARD WOOOHOOO?: ", unmaskedCard);
    refetch();
  };

  return (
    <>
      <h1 className="text-xl">absolutely mental poker</h1>

      {!isConnected && <ConnectButton />}
      {isConnected && <Account />}

      {isConnected && (
        <>
          <p>
            Current Aggregate Key:{" "}
            {!isLoading ? currentAggregateKey?.toString?.() : "loading..."}
          </p>
          <form onSubmit={submitAggregateKey}>
            <input
              name="sk"
              type="number"
              placeholder="Enter a secret key"
              value={sk}
              onChange={(e) => setSk(e.target.value)}
            />
            <button type="submit">Submit</button>
          </form>
          {error && <p className="text-red-500">{error}</p>}

          <h1>Deck:</h1>
          <ul>
            {deck?.map?.((card, i) => (
              <li key={i}>{card.toString()}</li>
            ))}
          </ul>
          <button onClick={shuffleDeck}>Shuffle Deck</button>
          <br />
          <button onClick={dealCard}>Deal Card</button>
        </>
      )}
    </>
  );
}
