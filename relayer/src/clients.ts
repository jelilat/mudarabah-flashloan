import { createPublicClient, createWalletClient, http } from "viem";
import { sepolia } from "viem/chains";
import { privateKeyToAccount } from "viem/accounts";
import dotenv from "dotenv";

// Load environment variables
dotenv.config();

// Validate required environment variables
const requiredEnvVars = [
  "RPC_URL",
  "RELAYER_PRIVATE_KEY",
  "LOAN_TOKEN_ADDRESS",
  "PROFIT_TOKEN_ADDRESS",
  "MIZAN_ADDRESS",
  "BORROWER_ADDRESS",
];

for (const envVar of requiredEnvVars) {
  if (!process.env[envVar]) {
    throw new Error(`Missing required environment variable: ${envVar}`);
  }
}

// Initialize clients
export const publicClient = createPublicClient({
  chain: sepolia,
  transport: http(),
});

// Ensure private key is properly formatted
const privateKey = process.env.RELAYER_PRIVATE_KEY;
if (!privateKey?.startsWith("0x")) {
  throw new Error("RELAYER_PRIVATE_KEY must start with 0x");
}

export const account = privateKeyToAccount(privateKey as `0x${string}`);
export const walletClient = createWalletClient({
  account,
  chain: sepolia,
  transport: http(process.env.RPC_URL as string),
});

// Export contract addresses
export const MIZAN_ADDRESS = process.env.MIZAN_ADDRESS as `0x${string}`;
export const LOAN_TOKEN_ADDRESS = process.env
  .LOAN_TOKEN_ADDRESS as `0x${string}`;
export const PROFIT_TOKEN_ADDRESS = process.env
  .PROFIT_TOKEN_ADDRESS as `0x${string}`;
export const BORROWER_ADDRESS = process.env.BORROWER_ADDRESS as `0x${string}`;
