import {
  type Hash,
  type Log,
  type TransactionReceipt,
  decodeFunctionData,
  recoverMessageAddress,
} from "viem";
import { mizanAbi } from "./abis/mizan";
import { borrowerStrategyAbi } from "./abis/borrowerStrategy";
import { publicClient, walletClient, MIZAN_ADDRESS } from "./clients";
import express from "express";
import type { Request, Response } from "express";
import { z } from "zod";
import {
  flashLoanRequest,
  generateSignature,
  shouldProceedWithFailedSimulation,
} from "./simulate";
import { calculateProfitByToken } from "./profit-calculator";
import { setupProcessor, processTraceCall } from "./transfer-processor";
import type { ProfitMetadata, TraceCall } from "./types";

/**
 * DISCLAIMER: This is an experimental implementation and has not been audited.
 * Use at your own risk. The code is provided as-is with no guarantees of security,
 * correctness, or fitness for any particular purpose.
 */

// Request validation schema
const FlashLoanRequestSchema = z.object({
  token: z.string().startsWith("0x"),
  amount: z.string(),
  strategy: z.string().startsWith("0x"),
  userSignature: z.string().startsWith("0x"),
  message: z.string(), // The message that was signed
});

interface SimulationResponse {
  result: {
    status: boolean;
    trace: TraceCall[];
  };
}

// Express app
const app = express();
app.use(express.json());

// Handle flash loan request
app.post("/flashloan", async (req: Request, res: Response) => {
  try {
    // Validate request
    const { token, amount, strategy, userSignature, message } =
      FlashLoanRequestSchema.parse(req.body);

    // Verify signature and recover borrower address
    const borrower = await recoverMessageAddress({
      message: { raw: message as `0x${string}` },
      signature: userSignature as `0x${string}`,
    });

    // Simulate the transaction
    const result = await flashLoanRequest(BigInt(amount));
    const simResponse = result as SimulationResponse;
    const trace = simResponse.result.trace;

    // Check if we should proceed with the transaction
    if (
      !simResponse.result.status &&
      !shouldProceedWithFailedSimulation(trace)
    ) {
      return res
        .status(400)
        .json({ error: "Simulation failed and should not proceed" });
    }

    // Process the trace to calculate profits
    setupProcessor(trace[0].to, borrower);
    await processTraceCall(trace);
    const profitMetadata = calculateProfitByToken();

    if (profitMetadata.length === 0) {
      return res.status(400).json({ error: "No profit detected" });
    }

    // Generate signature with updated metadata
    const [relayerSignature, expiry, nonce] = await generateSignature(
      BigInt(amount),
      profitMetadata
    );

    // Simulate the final transaction
    const { request } = await publicClient.simulateContract({
      address: strategy as `0x${string}`,
      abi: borrowerStrategyAbi,
      functionName: "requestFlashLoan",
      args: [
        token as `0x${string}`,
        BigInt(amount),
        {
          profits: profitMetadata,
          expiry,
          nonce,
        },
        relayerSignature,
      ],
    });

    // Execute flash loan
    const hash = await walletClient.writeContract(request);

    res.json({
      success: true,
      hash,
      profits: profitMetadata.map((p) => ({
        taker: p.taker,
        token: p.token,
      })),
    });
  } catch (error) {
    console.error("Error handling flash loan request:", error);
    res.status(500).json({ error: "Internal server error" });
  }
});

// Start server
const port = process.env.PORT || 3000;
app.listen(port, () => {
  console.log(`Relayer server listening on port ${port}`);
});
