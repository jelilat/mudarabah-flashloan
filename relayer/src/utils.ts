import { publicClient } from "./clients";
import type { TraceCall } from "./types";
import { WETH_LIKE_TOKENS, WETH_FUNCTION_SIGNATURES } from "./constants";

/**
 * Check if a token is WETH-like by examining its contract code
 */
export async function isWethLikeToken(tokenAddress: string): Promise<boolean> {
  try {
    // Skip if already known
    if (WETH_LIKE_TOKENS.has(tokenAddress)) {
      return true;
    }

    // Get contract code
    const code = await publicClient.getCode({
      address: tokenAddress as `0x${string}`,
    });
    if (!code || code === "0x") {
      return false;
    }

    // Check for WETH-like function signatures
    const hasWethFunctions = WETH_FUNCTION_SIGNATURES.some((sig) =>
      code.includes(sig)
    );

    if (hasWethFunctions) {
      // Add to known WETH-like tokens
      WETH_LIKE_TOKENS.add(tokenAddress);
      return true;
    }

    return false;
  } catch (error) {
    console.error(`Error checking WETH-like token ${tokenAddress}: ${error}`);
    return false;
  }
}
