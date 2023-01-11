import { groth16 } from "snarkjs";
import { BigNumber } from "ethers";

// TODO: hook into snarkjs to get this data before it's stringified
export async function exportSolidityCallDataGroth16({ proof, publicSignals }: any) {
  const rawCallData: string = await groth16.exportSolidityCallData(proof, publicSignals);
  const tokens = rawCallData
    .replace(/["[\]\s]/g, "")
    .split(",")
    .map(BigNumber.from);
  const [a1, a2, b1, b2, b3, b4, c1, c2, ...inputs] = tokens;
  const a = [a1, a2] satisfies [BigNumber, BigNumber];
  const b = [
    [b1, b2],
    [b3, b4],
  ] satisfies [[BigNumber, BigNumber], [BigNumber, BigNumber]];
  const c = [c1, c2] satisfies [BigNumber, BigNumber];
  return {
    a, b, c,
    inputs
  }
}
