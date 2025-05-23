import type { TransferLog, TraceCall } from "./types";
import type { TokenBalanceChangeByAddress } from "./types";
import { isWethLikeToken } from "./utils";
import { NULL_ADDRESS, ETH_ADDRESS } from "./constants";
import dotenv from "dotenv";

dotenv.config();

// State management
export const revenueBalanceChanges: TokenBalanceChangeByAddress = {};
export const costBalanceChanges: TokenBalanceChangeByAddress = {};
export interface AddressParticipationData {
  toCount: number;
  fromCount: number;
  participation: number;
}
export const addressParticipation: {
  [address: `0x${string}`]: {
    [token: `0x${string}`]: AddressParticipationData;
  };
} = {};

// Configuration variables
let contractAddress = "";
let senderAddress = "";
/**
 * Initialize balance changes for a token and address
 */
export function initializeBalanceChanges(
  token: `0x${string}`,
  address: `0x${string}`,
  isRevenue: boolean,
  isSenderOrContract: boolean
): void {
  if (address === "0x0") {
    return;
  }

  const balanceChanges = isRevenue ? revenueBalanceChanges : costBalanceChanges;

  if (!balanceChanges[token]) balanceChanges[token] = {};

  if (!balanceChanges[token][address]) {
    if (isSenderOrContract) {
      balanceChanges[token][address] = {
        amount: 0n,
        type: isRevenue ? "Revenue" : "Cost",
      };
    } else {
      balanceChanges[token][address] = {
        amount: 0n,
        type: "TokenTransfer",
      };
    }
  }
}

/**
 * Track address participation in transfers
 */
export function trackAddressParticipation(
  from: `0x${string}`,
  to: `0x${string}`,
  token: `0x${string}`
): void {
  // Initialize address data if not exists
  if (!addressParticipation[from]) addressParticipation[from] = {};
  if (!addressParticipation[to]) addressParticipation[to] = {};

  // Initialize token data for addresses if not exists
  if (!addressParticipation[from][token]) {
    addressParticipation[from][token] = {
      toCount: 0,
      fromCount: 0,
      participation: 0,
    };
  }

  if (!addressParticipation[to][token]) {
    addressParticipation[to][token] = {
      toCount: 0,
      fromCount: 0,
      participation: 0,
    };
  }

  // Update counts
  if (addressParticipation[from][token].fromCount === 0) {
    addressParticipation[from][token].participation++;
  }
  addressParticipation[from][token].fromCount++;

  if (addressParticipation[to][token].toCount === 0) {
    addressParticipation[to][token].participation++;
  }
  addressParticipation[to][token].toCount++;
}

/**
 * Process a transfer of tokens between addresses
 */
export function processTransfer(
  token: `0x${string}`,
  from: `0x${string}`,
  to: `0x${string}`,
  amount: bigint
): void {
  trackAddressParticipation(from, to, token);

  // Initialize balance changes
  const isFromSenderOrContract =
    from.toLowerCase() === senderAddress ||
    from.toLowerCase() === contractAddress;
  const isToSenderOrContract =
    to.toLowerCase() === senderAddress || to.toLowerCase() === contractAddress;

  initializeBalanceChanges(token, to, true, isToSenderOrContract);
  initializeBalanceChanges(token, from, false, isFromSenderOrContract);

  // Update balances
  if (to !== NULL_ADDRESS) {
    revenueBalanceChanges[token][to].amount += amount;
  }

  if (from !== NULL_ADDRESS) {
    costBalanceChanges[token][from].amount -= amount;
  }
}

/**
 * Process trace calls recursively to catch ETH transfers
 */
export const processTraceCall = async (calls: TraceCall[]): Promise<void> => {
  try {
    if (!calls || calls.length === 0) {
      console.log("No trace calls to process");
      return;
    }

    let processedCalls = 0;

    for (const call of calls) {
      try {
        // Handle ETH transfers
        if (call.type === "CALL" && call.value && call.value !== "0x0") {
          const token = ETH_ADDRESS as `0x${string}`;
          const from = call.from.toLowerCase() as `0x${string}`;
          const to = call.to.toLowerCase() as `0x${string}`;
          const amount = BigInt(call.value);

          console.log(
            `ETH Transfer: ${from} -> ${to}, amount: ${amount.toString()}`
          );
          processTransfer(token, from, to, amount);
          processedCalls++;
        }
        // Handle ERC20 transfers and WETH-like operations
        else if (call.type === "CALL" && call.input) {
          const input = call.input.slice(0, 10); // Get function signature
          const token = call.to.toLowerCase() as `0x${string}`;

          // Check if this is a WETH-like token
          const isWethLike = await isWethLikeToken(token);

          // transfer(address,uint256)
          if (input === "0xa9059cbb") {
            const [to, amount] = decodeTransferInput(call.input);
            const from = call.from.toLowerCase() as `0x${string}`;

            console.log(
              `ERC20 Transfer: ${from} -> ${to}, token: ${token}, amount: ${amount.toString()}`
            );
            processTransfer(token, from, to, amount);
            processedCalls++;
          }
          // transferFrom(address,address,uint256)
          else if (input === "0x23b872dd") {
            const [from, to, amount] = decodeTransferFromInput(call.input);

            console.log(
              `ERC20 TransferFrom: ${from} -> ${to}, token: ${token}, amount: ${amount.toString()}`
            );
            processTransfer(token, from, to, amount);
            processedCalls++;
          }
          // deposit() - WETH-like
          else if (input === "0xd0e30db0" && isWethLike) {
            const amount = BigInt(call.value || "0");
            const from = call.from.toLowerCase() as `0x${string}`;

            console.log(`WETH Deposit: ${from}, amount: ${amount.toString()}`);
            // Treat it like a WETH transfer in
            processTransfer(token, NULL_ADDRESS, from, amount);
            processedCalls++;
          }
          // withdraw(uint256) - WETH-like
          else if (input === "0x2e1a7d4d" && isWethLike) {
            const amount = decodeWithdrawInput(call.input);
            const from = call.from.toLowerCase() as `0x${string}`;

            console.log(`WETH Withdraw: ${from}, amount: ${amount.toString()}`);
            // Treat it like a WETH transfer out
            processTransfer(token, from, NULL_ADDRESS, amount);
            processedCalls++;
          }
        }

        if (call.calls && call.calls.length > 0) {
          // Recursively process nested calls
          await processTraceCall(call.calls);
        }
      } catch (error) {
        console.error(`Error processing trace call: ${error}`);
      }
    }
  } catch (error) {
    console.error(`Failed to process trace calls: ${error}`);
  }
};

// Helper functions to decode ERC20 function inputs
function decodeTransferInput(input: string): [`0x${string}`, bigint] {
  const data = input.slice(10); // Remove function signature
  const to = `0x${data.slice(24, 64)}` as `0x${string}`;
  const amount = BigInt(`0x${data.slice(64, 128)}`);
  return [to, amount];
}

function decodeTransferFromInput(
  input: string
): [`0x${string}`, `0x${string}`, bigint] {
  const data = input.slice(10); // Remove function signature
  const from = `0x${data.slice(24, 64)}` as `0x${string}`;
  const to = `0x${data.slice(88, 128)}` as `0x${string}`;
  const amount = BigInt(`0x${data.slice(128, 192)}`);
  return [from, to, amount];
}

function decodeWithdrawInput(input: string): bigint {
  const data = input.slice(10); // Remove function signature
  return BigInt(`0x${data.slice(24, 64)}`);
}

/**
 * Setup the processor with contract and sender addresses
 */
export function setupProcessor(contract: string, sender: string): void {
  contractAddress = contract.toLowerCase();
  senderAddress = sender.toLowerCase();
}
