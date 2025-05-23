// Common interfaces]
export interface AddressBalance {
  amount: bigint;
  type: "Revenue" | "Cost" | "TokenTransfer";
}
export interface TokenBalanceChangeByAddress {
  [token: `0x${string}`]: {
    [address: `0x${string}`]: AddressBalance;
  };
}

export interface TransferLog {
  name: string;
  anonymous: boolean;
  raw: {
    address: string;
    topics: string[];
    data: string;
  };
  inputs: {
    value: number | string;
    type: string;
    name: string;
    indexed: boolean;
  }[];
}

export interface TraceCall {
  from: `0x${string}`;
  to: `0x${string}`;
  value?: string;
  type: string;
  input: string;
  output?: string;
  error?: string;
  errorReason?: string;
  gas: string;
  gasUsed: string;
  calls?: TraceCall[];
}

export type ProfitMetadata = {
  token: `0x${string}`;
  taker: `0x${string}`;
};
