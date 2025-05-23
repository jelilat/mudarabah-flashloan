export const mizanAbi = [
  {
    type: "constructor",
    inputs: [
      { name: "_underlyingToken", type: "address", internalType: "address" },
      { name: "_relayer", type: "address", internalType: "address" },
    ],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "relayer",
    inputs: [],
    outputs: [{ name: "", type: "address", internalType: "address" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "hashProfitMetadata",
    inputs: [
      {
        name: "data",
        type: "tuple[]",
        internalType: "struct FlashLoan.ProfitMetadata[]",
        components: [
          { name: "taker", type: "address", internalType: "address" },
          { name: "token", type: "address", internalType: "address" },
        ],
      },
    ],
    outputs: [{ name: "", type: "bytes32", internalType: "bytes32" }],
    stateMutability: "pure",
  },
  {
    type: "function",
    name: "hashFlashLoanRequest",
    inputs: [
      { name: "loanToken", type: "address", internalType: "address" },
      { name: "loanAmount", type: "uint256", internalType: "uint256" },
      { name: "expiry", type: "uint256", internalType: "uint256" },
      { name: "nonce", type: "bytes32", internalType: "bytes32" },
      { name: "profitHash", type: "bytes32", internalType: "bytes32" },
    ],
    outputs: [{ name: "", type: "bytes32", internalType: "bytes32" }],
    stateMutability: "pure",
  },
  {
    type: "function",
    name: "requestFlashLoan",
    inputs: [
      { name: "_loanToken", type: "address", internalType: "address" },
      { name: "loanAmount", type: "uint256", internalType: "uint256" },
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
              { name: "taker", type: "address", internalType: "address" },
              { name: "token", type: "address", internalType: "address" },
            ],
          },
          { name: "expiry", type: "uint256", internalType: "uint256" },
          { name: "nonce", type: "bytes32", internalType: "bytes32" },
        ],
      },
      { name: "signature", type: "bytes", internalType: "bytes" },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "toEthSignedMessageHash",
    inputs: [{ name: "hash", type: "bytes32" }],
    outputs: [{ name: "", type: "bytes32" }],
    stateMutability: "pure",
  },
  {
    type: "function",
    name: "recover",
    inputs: [
      { name: "hash", type: "bytes32" },
      { name: "signature", type: "bytes" },
    ],
    outputs: [{ name: "", type: "address" }],
    stateMutability: "pure",
  },
] as const;
