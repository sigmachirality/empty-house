import "./index.css";
import React, { useEffect, useState } from "react";
import Confetti from "react-confetti";
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
import Patrick from "./constants/patrick.gif";
import Lobby from "./constants/lobby.png";
const { VITE_MENTAL_POKER_ADDRESS } = import.meta.env;

import { R } from "./constants/field";
import { coerceToBigInt, marshallCardArray } from "./constants/cards";
import { groth16 } from "snarkjs";
import { exportSolidityCallDataGroth16 as exportSolidityCallData } from "./utils/snark-helpers";

import {
  sampleFieldElement,
  sampleMaskingFactors,
  samplePermutationMatrix,
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
  const [lobbyNumber, setLobbyNumber] = useState<number>();
  const [sk, setSk] = useState<string>(sampleFieldElement().toString());
  const [gameJoined, setGameJoined] = useState<boolean>(false);
  const [unmaskedCard, setUnmaskedCard] = useState<BigNumber>();

  const { data: signer } = useSigner();
  const { isConnected, address } = useAccount();
  const MentalPoker = useContract({
    address: VITE_MENTAL_POKER_ADDRESS,
    abi: MentalPokerABI.abi,
    signerOrProvider: signer,
  }) as MentalPoker;

  // TODO: This is a hack to get the player number. We should be using useContractEvent
  const [playerNumber, setPlayerNumber] = useState<number>();
  useEffect(() => {
    if (!isConnected) return;
    const playerNumber =
      ("0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266" as const) === address
        ? 0
        : 1;
    setPlayerNumber(playerNumber);
  }, [address, isConnected]);

  // useContractEvent({
  //   address: VITE_MENTAL_POKER_ADDRESS,
  //   abi: MentalPokerABI.abi,
  //   eventName: "AggregateKeyUpdated",
  //   listener: (_, __, owner: any) => {
  //     setPlayerNumber(owner.args._playerNum.toNumber());
  //   },
  // });

  const { data, refetch, isLoading } = useQuery({
    queryKey: ["getCurrentAggregateKey"],
    queryFn: async () => {
      return (
        lobbyNumber &&
        (await Promise.all([
          MentalPoker.getCurrentAggregateKey(lobbyNumber),
          MentalPoker.getDeck(lobbyNumber),
        ]))
      );
    },
    refetchInterval: 100,
    refetchOnMount: true,
  });
  const [currentAggregateKey, deck] = data || [];

  const submitAggregateKey = async (
    event: React.FormEvent<HTMLFormElement>
  ) => {
    event.preventDefault();
    if (MentalPoker === null || !lobbyNumber) {
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
      // Fetch current aggregate key
      const oldAggregateKey = await MentalPoker.getCurrentAggregateKey(
        lobbyNumber
      );
      const oldAggregateBigInt = oldAggregateKey.toBigInt();

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
      await MentalPoker.updateAggregateKey(lobbyNumber, {
        a,
        b,
        c,
        old_aggk: oldAggregateKey,
        new_aggk: newAggregateKey,
        pk,
      });

      // setPlayerNumber(response.value.toNumber());
      refetch();
      setGameJoined(true);
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
    // TODO: use Zod when this "||" becomes too large
    if (MentalPoker === null || !deck || !currentAggregateKey || !lobbyNumber) {
      setError("Unable to connect to contract. Are you on the right network?");
      return;
    }
    const { proof, publicSignals } = await groth16.fullProve(
      {
        agg_pk: currentAggregateKey.toBigInt(),
        permutation_matrix: samplePermutationMatrix(),
        input_tuples: deck.map((tuple) => tuple.map(coerceToBigInt)),
        randomness: sampleMaskingFactors(),
      },
      ShuffleCards,
      ShuffleCardsZKey
    );
    const { a, b, c, inputs } = await exportSolidityCallData({
      proof,
      publicSignals,
    });
    const maskedCards = marshallCardArray(inputs.slice(0, 12));

    await MentalPoker.encrypt(lobbyNumber, {
      a,
      b,
      c,
      input_tuples: deck,
      aggk: currentAggregateKey,
      output_tuples: maskedCards,
    });
    refetch();
  };

  const dealCard = async (playerNumber: number) => {
    const otherPlayer = playerNumber === 1 ? 0 : 1;

    if (MentalPoker === null || !deck || !lobbyNumber) {
      // TODO: more descriptive errors (maybe Zod?)
      setError("Unable to connect to contract. Are you on the right network?");
      return;
    }
    const { proof, publicSignals } = await groth16.fullProve(
      {
        masked_card: deck[otherPlayer].map(coerceToBigInt),
        sk: BigInt(sk),
      },
      DealCard,
      DealCardZKey
    );
    const { a, b, c, inputs } = await exportSolidityCallData({
      proof,
      publicSignals,
    });
    const [pk, unmaskedCard] = inputs;

    // Todo: change card number based on player number
    await MentalPoker.decrypt(lobbyNumber, otherPlayer, {
      a,
      b,
      c,
      masked_card: deck[otherPlayer],
      unmasked_card: unmaskedCard,
      pk,
    });
    refetch();
  };

  const recieveCard = async (playerNumber: number) => {
    if (MentalPoker === null || !deck) {
      // TODO: more descriptive errors (maybe Zod?)
      setError("Unable to connect to contract. Are you on the right network?");
      return;
    }
    const { proof, publicSignals } = await groth16.fullProve(
      {
        masked_card: deck[playerNumber].map(coerceToBigInt),
        sk: BigInt(sk),
      },
      DealCard,
      DealCardZKey
    );
    const { a, b, c, inputs } = await exportSolidityCallData({
      proof,
      publicSignals,
    });
    const [pk, unmaskedCard] = inputs;
    setUnmaskedCard(unmaskedCard);

    // Todo: change card number based on player number
    // await MentalPoker.decrypt(otherPlayer, {
    //   a,
    //   b,
    //   c,
    //   masked_card: deck[otherPlayer],
    //   unmasked_card: unmaskedCard,
    //   pk,
    // });
    refetch();
  };

  return (
    <>
      {unmaskedCard && <Confetti />}
      {
        <div className="flex flex-col min-h-screen px-2 bg-slate-900 text-slate-300">
          <header className="flex flex-wrap justify-between p-5 mb-5">
            <a className="text-xl md:mb-auto mb-5 font-bold text-transparent bg-clip-text bg-gradient-to-r from-sky-500 to-orange-500">
              absolutely mental poker
            </a>
            <div className="flex justify-center items-center">
              <ConnectButton />
            </div>
          </header>
          <main className="mb-auto">
            {(isConnected && gameJoined) || (
              <>
                <div className="flex justify-center items-center">
                  <span className="mb-10 text-3xl font-bold text-transparent bg-clip-text bg-gradient-to-r from-sky-500 to-orange-500 ">
                    Ready to play a game?
                  </span>
                </div>
                {isLoading ? (
                  <>
                    <div className="animate-spin flex flex-col flex-wrap justify-center items-center md:gap-5 gap-10">
                      <img className="animate-spin" src={Patrick} />
                    </div>
                    <div className="animate-spin flex flex-col flex-wrap justify-center items-center md:gap-5 gap-10">
                      <h3 className="text-lg">loading...</h3>
                    </div>
                  </>
                ) : (
                  <form
                    className="flex flex-wrap justify-center items-center md:gap-10 gap-20"
                    onSubmit={submitAggregateKey}
                  >
                    <img className="rounded-xl" src={Lobby} />
                    <div>
                      <div className="mb-6">
                        <label
                          htmlFor="lobby"
                          className="block mb-2 text-sm font-medium text-gray-900 dark:text-white"
                        >
                          Lobby Number
                        </label>
                        <input
                          className="flex justify-center items-center space-x-1 transition-colors duration-150 mb-4 text-lg text-sky-600 font-semibold py-3 px-5 rounded-md bg-white  hover:from-sky-500 hover:to-orange-500"
                          name="lobby"
                          type="number"
                          placeholder="Enter a lobby number"
                          value={lobbyNumber}
                          onChange={(e) =>
                            setLobbyNumber(parseInt(e.target.value))
                          }
                        />{" "}
                      </div>

                      <div className="mb-6">
                        <label
                          htmlFor="sk"
                          className="block mb-2 text-sm font-medium text-gray-900 dark:text-white"
                        >
                          Your secret key
                        </label>
                        <input
                          className="flex justify-center items-center space-x-1 transition-colors duration-150 mb-4 text-lg text-sky-600 font-semibold py-3 px-5 rounded-md bg-white  hover:from-sky-500 hover:to-orange-500"
                          name="sk"
                          type="number"
                          placeholder="Enter a secret key"
                          value={sk}
                          onChange={(e) => setSk(e.target.value)}
                        />{" "}
                      </div>

                      <button
                        className="flex justify-center items-center space-x-1 transition-colors duration-150 mb-4 text-lg text-slate-300 font-semibold py-3 px-5 rounded-md bg-gradient-to-r from-sky-600 to-orange-600 hover:from-sky-500 hover:to-orange-500"
                        type="submit"
                      >
                        Join
                      </button>
                      {error && <p className="text-red-500">{error}</p>}
                    </div>
                  </form>
                )}
              </>
            )}

            {gameJoined && (
              <div className="flex justify-center items-center">
                <div>
                  <h1 className="mb-10 text-3xl font-bold text-transparent bg-clip-text bg-gradient-to-r from-sky-500 to-orange-500">
                    Lobby {currentAggregateKey?.toHexString?.().slice(0, 16)}:
                  </h1>
                  {unmaskedCard && (
                    <div className="flex justify-center items-center">
                      <div className="w-48 h-64 flex flex-col gap-10 px-12 py-20 justify-center items-center space-x-1 transition-colors duration-150 mb-4 text-lg text-sky-600 font-semibold rounded-md bg-white hover:from-sky-500 hover:to-orange-500 mb-12">
                        {unmaskedCard?.toString?.()}
                      </div>
                    </div>
                  )}

                  <div className="flex flex-wrap justify-center items-center md:gap-5 gap-10 flex-row">
                    {deck?.map?.((card, i) => (
                      <div className="flex flex-col gap-10 px-12 py-20 justify-center items-center space-x-1 transition-colors duration-150 mb-4 text-lg text-sky-600 font-semibold rounded-md bg-white hover:from-sky-500 hover:to-orange-500">
                        <div>{card[0].toString().slice(0, 6)}...</div>
                        <div>{card[1].toString().slice(0, 6)}...</div>
                      </div>
                    ))}
                  </div>
                  <span className="flex justify-center items-center gap-5">
                    <button
                      className="flex justify-center items-center space-x-1 transition-colors duration-150 mb-4 text-lg text-slate-300 font-semibold py-3 px-5 rounded-md bg-sky-600 bg-gradient-to-r  hover:from-sky-500 hover:to-orange-500"
                      onClick={shuffleDeck}
                    >
                      Shuffle Deck
                    </button>
                    <button
                      className="flex justify-center items-center space-x-1 transition-colors duration-150 mb-4 text-lg text-slate-300 font-semibold py-3 px-5 rounded-md bg-orange-600 bg-gradient-to-r hover:from-sky-500 hover:to-orange-500"
                      onClick={() => dealCard(playerNumber!)}
                    >
                      Deal Card
                    </button>
                    <button
                      className="flex justify-center items-center space-x-1 transition-colors duration-150 mb-4 text-lg text-slate-300 font-semibold py-3 px-5 rounded-md bg-gradient-to-r from-sky-600 to-orange-600 hover:from-sky-500 hover:to-orange-500"
                      onClick={() => recieveCard(playerNumber!)}
                    >
                      Recieve Card
                    </button>
                  </span>
                </div>
              </div>
            )}
          </main>
        </div>
      }
    </>
  );
}
