import { BigNumberish, BigNumber } from "ethers";

export const NUM_CARDS = 52 as const;
const NUM_CARDS_SS = 54 as const; // Successor of successor of num cards

type Enumerate<N extends number, Acc extends number[] = []> = Acc['length'] extends N
  ? Acc[number]
  : Enumerate<N, [...Acc, Acc['length']]>
type IntRange<F extends number, T extends number> = Exclude<Enumerate<T>, Enumerate<F>>

export type Tuple<T, N extends number> = N extends N ? number extends N ? T[] : _TupleOf<T, N, []> : never;
type _TupleOf<T, N extends number, R extends unknown[]> = R['length'] extends N ? R : _TupleOf<T, N, [T, ...R]>;

export type Card = IntRange<0, typeof NUM_CARDS>;
export type CardPoint = IntRange<2, typeof NUM_CARDS_SS>;

export const cardToPoint = (card: Card) => (card + 2) as CardPoint;
export const pointToCard = (point: CardPoint) => (point - 2) as Card;

export type Deck = Tuple<Card, typeof NUM_CARDS>;
export const ORDERED_CARDS = Array(NUM_CARDS).map((_, i) => i) as Deck;
export const ORDERED_POINTS = ORDERED_CARDS.map(card => [1, cardToPoint(card)] as const) as Tuple<[1, CardPoint], typeof NUM_CARDS>;

export function coerceToBigInt(card: BigNumberish): bigint {
  return BigNumber.from(card).toBigInt();
}

export function marshallCardArray(flatCards: BigNumberish[]): [BigNumberish, BigNumberish][] {
  const ret: [BigNumberish, BigNumberish][] = [];
  for (let i = 0; i < flatCards.length; i+=2) {
    ret.push([flatCards[i], flatCards[i+1]]);
  }
  return ret;
}
