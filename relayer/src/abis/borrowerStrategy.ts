export const borrowerStrategyAbi = [
  {
    type: "constructor",
    inputs: [
      {
        name: "_mizan",
        type: "address",
        internalType: "address",
      },
      {
        name: "_profitToken",
        type: "address",
        internalType: "address",
      },
      {
        name: "_profitAmount",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "executeStrategy",
    inputs: [
      {
        name: "loanToken",
        type: "address",
        internalType: "address",
      },
      {
        name: "loanAmount",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    outputs: [
      {
        name: "",
        type: "bool",
        internalType: "bool",
      },
    ],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "mizan",
    inputs: [],
    outputs: [
      {
        name: "",
        type: "address",
        internalType: "address",
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "profitAmount",
    inputs: [],
    outputs: [
      {
        name: "",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "profitToken",
    inputs: [],
    outputs: [
      {
        name: "",
        type: "address",
        internalType: "address",
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "requestFlashLoan",
    inputs: [
      {
        name: "loanToken",
        type: "address",
        internalType: "address",
      },
      {
        name: "loanAmount",
        type: "uint256",
        internalType: "uint256",
      },
      {
        name: "meta",
        type: "tuple",
        internalType: "struct FlashLoan.FlashLoanMeta",
        components: [
          {
            name: "profits",
            type: "tuple[]",
            internalType: "struct FlashLoan.ProfitMetadata[]",
            components: [
              {
                name: "taker",
                type: "address",
                internalType: "address",
              },
              {
                name: "token",
                type: "address",
                internalType: "address",
              },
            ],
          },
          {
            name: "expiry",
            type: "uint256",
            internalType: "uint256",
          },
          {
            name: "nonce",
            type: "bytes32",
            internalType: "bytes32",
          },
        ],
      },
      {
        name: "signature",
        type: "bytes",
        internalType: "bytes",
      },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "error",
    name: "SafeERC20FailedOperation",
    inputs: [
      {
        name: "token",
        type: "address",
        internalType: "address",
      },
    ],
  },
] as const;
