import dotenv from "dotenv";
import {
  account,
  BORROWER_ADDRESS,
  LOAN_TOKEN_ADDRESS,
  PROFIT_TOKEN_ADDRESS,
  publicClient,
  walletClient,
} from "./clients";
import { setupProcessor, processTraceCall } from "./transfer-processor";
import { calculateProfitByToken } from "./profit-calculator";
import {
  flashLoanRequest,
  shouldProceedWithFailedSimulation,
  generateSignature,
} from "./simulate";
import type { TraceCall } from "./types";
import { borrowerStrategyAbi } from "./abis/borrowerStrategy";

// Load environment variables
dotenv.config();

// Validate required environment variables
const requiredEnvVars = [
  "BORROWER_ADDRESS",
  "LOAN_TOKEN_ADDRESS",
  "PROFIT_TOKEN_ADDRESS",
  "MIZAN_ADDRESS",
  "RELAYER_PRIVATE_KEY",
  "RPC_URL",
];

for (const envVar of requiredEnvVars) {
  if (!process.env[envVar]) {
    throw new Error(`Missing required environment variable: ${envVar}`);
  }
}

interface SimulationResponse {
  result: {
    status: boolean;
    trace: TraceCall[];
  };
}

// Example usage
flashLoanRequest(BigInt(1000000000000000000))
  .then(async (response: unknown) => {
    const simResponse = response as SimulationResponse;
    console.log("Success:", simResponse);
    const result = simResponse.result;
    const trace = result.trace;
    if (result.status === true || shouldProceedWithFailedSimulation(trace)) {
      console.log("Proceeding with profit calculation");
      setupProcessor(trace[0].to, account.address);
      await processTraceCall(trace);
      const profitMetadata = calculateProfitByToken();
      const [signature, expiry, nonce] = await generateSignature(
        BigInt(1000000000000000000),
        profitMetadata
      );
      // send transaction
      const { request } = await publicClient.simulateContract({
        address: BORROWER_ADDRESS,
        abi: borrowerStrategyAbi,
        functionName: "requestFlashLoan",
        args: [
          LOAN_TOKEN_ADDRESS,
          BigInt(1000000000000000000),
          {
            profits: profitMetadata,
            expiry,
            nonce,
          },
          signature,
        ],
      });
      const tx = await walletClient.writeContract(request);
      console.log("Transaction sent:", tx);
    } else {
      console.log("Not proceeding with profit calculation");
    }
  })
  .catch((error) => console.error("Test failed:", error));
