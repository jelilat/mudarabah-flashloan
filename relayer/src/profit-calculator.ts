import type { ProfitMetadata, AddressBalance } from "./types";
import {
  revenueBalanceChanges,
  addressParticipation,
} from "./transfer-processor";
import { NULL_ADDRESS } from "./constants";

/**
 * Calculates the total profit for each token
 */
export function calculateProfitByToken(): ProfitMetadata[] {
  const profitTakers: ProfitMetadata[] = [];

  for (const token in revenueBalanceChanges) {
    let index = 0;

    // Get profit takers
    Object.values(revenueBalanceChanges[token as `0x${string}`]).reduce(
      (sum: bigint, balance: AddressBalance) => {
        if (balance.type === "Revenue" || balance.type === "Cost") {
          index++;
          return sum + balance.amount;
        }

        const address = Object.keys(
          revenueBalanceChanges[token as `0x${string}`]
        )[index] as `0x${string}`;

        // get totalAddressParticipation
        let totalParticipation = 0;
        for (const token in addressParticipation[address]) {
          totalParticipation +=
            addressParticipation[address][token as `0x${string}`].participation;
        }

        // The address is a profit taker if it receives a token transfer without sending any tokens
        // i.e. It is not a swap
        if (
          totalParticipation % 2 === 1 &&
          !revenueBalanceChanges[address] &&
          address !== NULL_ADDRESS
        ) {
          console.log(
            `${address} is a profit taker with ${addressParticipation[address][token as `0x${string}`].participation} participations`
          );
          profitTakers.push({ token: token as `0x${string}`, taker: address });
          index++;
          return sum + balance.amount;
        }

        index++;
        return sum;
      },
      0n
    );
  }

  return profitTakers;
}
