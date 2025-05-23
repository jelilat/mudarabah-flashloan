import {
  account,
  publicClient,
  walletClient,
  BORROWER_ADDRESS,
  LOAN_TOKEN_ADDRESS,
  PROFIT_TOKEN_ADDRESS,
} from "./clients";
import { borrowerStrategyAbi } from "./abis/borrowerStrategy";
import { mizanAbi } from "./abis/mizan";
import { keccak256, encodePacked, encodeFunctionData } from "viem";
import type { ProfitMetadata, TraceCall } from "./types";

export const MIZAN_ADDRESS = process.env.MIZAN_ADDRESS as `0x${string}`;

export const flashLoanRequest = async (loanAmount: bigint) => {
  try {
    // Check relayer address
    const contractRelayer = await publicClient.readContract({
      address: MIZAN_ADDRESS,
      abi: mizanAbi,
      functionName: "relayer",
    });
    if (contractRelayer.toLowerCase() !== account.address.toLowerCase()) {
      throw new Error("Relayer address mismatch");
    }

    // Create profit metadata
    const profitMetadata: ProfitMetadata[] = [
      {
        taker: BORROWER_ADDRESS,
        token: PROFIT_TOKEN_ADDRESS,
      },
    ];

    const [signature, expiry, nonce] = await generateSignature(
      loanAmount,
      profitMetadata
    );

    // Generate calldata
    const calldata = encodeFunctionData({
      abi: borrowerStrategyAbi,
      functionName: "requestFlashLoan",
      args: [
        LOAN_TOKEN_ADDRESS,
        loanAmount,
        {
          profits: profitMetadata,
          expiry,
          nonce,
        },
        signature,
      ],
    });

    const result = await simulateTransaction(
      account.address,
      BORROWER_ADDRESS,
      calldata,
      process.env.RPC_URL as string
    );
    return result;
  } catch (error) {
    console.error("Error in flashLoanRequest:", error);
    throw error;
  }
};

export const simulateTransaction = async (
  from: string,
  to: string,
  data: string,
  rpcUrl: string
) => {
  const body = {
    jsonrpc: "2.0",
    method: "tenderly_simulateTransaction",
    params: [
      {
        from,
        to,
        data,
        gas: "0x1000000",
      },
      "latest",
    ],
    id: 1,
  };
  const response = await fetch(rpcUrl, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  const result = await response.json();
  return result;
};

export function shouldProceedWithFailedSimulation(trace: TraceCall[]): boolean {
  // The error is always in the third call (index 2)
  const flashLoanCall = trace[2];

  return (
    flashLoanCall?.type === "DELEGATECALL" &&
    flashLoanCall?.errorReason === "FlashLoan: no profit detected"
  );
}

export const generateSignature = async (
  loanAmount: bigint,
  profitMetadata: ProfitMetadata[]
): Promise<[`0x${string}`, bigint, `0x${string}`]> => {
  // Hash profit metadata using contract
  const profitHash = await publicClient.readContract({
    address: MIZAN_ADDRESS,
    abi: mizanAbi,
    functionName: "hashProfitMetadata",
    args: [profitMetadata],
  });

  // Generate nonce and expiry
  const nonce = keccak256(
    encodePacked(
      ["uint256"],
      [BigInt(Math.floor(Math.random() * Number.MAX_SAFE_INTEGER))]
    )
  ) as `0x${string}`;
  const expiry = BigInt(Math.floor(Date.now() / 1000) + 3600);

  // Generate the message hash using the contract's hashFlashLoanRequest
  const messageHash = await publicClient.readContract({
    address: MIZAN_ADDRESS,
    abi: mizanAbi,
    functionName: "hashFlashLoanRequest",
    args: [LOAN_TOKEN_ADDRESS, loanAmount, expiry, nonce, profitHash],
  });

  // Sign the message hash
  const signature = await walletClient.signMessage({
    message: { raw: messageHash },
  });
  return [signature, expiry, nonce];
};
