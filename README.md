# Mudarabah Flash Loan

⚠️ **DISCLAIMER**: This is an experimental implementation and has not been audited. Use at your own risk. The code is provided as-is with no guarantees of security, correctness, or fitness for any particular purpose.

## Overview

This project implements a flash loan system with profit sharing capabilities. It consists of two main components:

1. **Smart Contracts**: Solidity contracts implementing the flash loan logic
2. **Relayer**: A TypeScript server that handles flash loan requests and profit calculations

## Components

### Smart Contracts

The smart contracts are located in the `contracts/` directory and include:

- `Mizan.sol`: Main contract implementing the flash loan functionality
- `MizanDepositToken.sol`: ERC20 token for deposits
- `MizanLoanToken.sol`: ERC20 token for loans
- `FlashLoan.sol`: Library for flash loan operations
- `LongTermLoan.sol`: Library for long-term loan operations

### Relayer

The relayer is located in the `relayer/` directory and provides:

- REST API for flash loan requests
- Transaction simulation
- Profit calculation
- Signature verification

## Setup

### Prerequisites

- Node.js (v16 or higher)
- Foundry
- A compatible Ethereum node (e.g., Infura, Alchemy)

### Environment Variables

Create a `.env` file in the root directory with the following variables:

```env
BORROWER_ADDRESS=0x...
LOAN_TOKEN_ADDRESS=0x...
PROFIT_TOKEN_ADDRESS=0x...
MIZAN_ADDRESS=0x...
RELAYER_PRIVATE_KEY=0x...
RPC_URL=https://...
```

### Installation

1. Install dependencies:
```bash
# Install Foundry dependencies
forge install

# Install Node.js dependencies
cd relayer
npm install
```

2. Build contracts:
```bash
forge build
```

3. Start the relayer server:
```bash
cd relayer
npm start
```

## API Usage

### Flash Loan Request

```http
POST /flashloan
Content-Type: application/json

{
  "token": "0x...",      // Token address to borrow
  "amount": "1000000",   // Amount to borrow (in wei)
  "strategy": "0x...",   // Strategy contract address
  "userSignature": "0x...", // User's signature
  "message": "..."       // Message that was signed
}
```

Response:
```json
{
  "success": true,
  "hash": "0x...",  // Transaction hash
  "profits": [
    {
      "taker": "0x...",
      "token": "0x..."
    }
  ]
}
```

## Development

### Running Tests

```bash
# Run Solidity tests
forge test

# Run TypeScript tests
cd relayer
npm test
```

## Security

⚠️ **IMPORTANT**: This code has not been audited and is provided for educational purposes only. Do not use in production without a thorough security audit.

## License

MIT License - see LICENSE file for details 