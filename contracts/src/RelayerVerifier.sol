// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IRelayerVerifier} from "./interfaces/IRelayerVerifier.sol";
import "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import "openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";

contract RelayerVerifier is IRelayerVerifier {
    address public immutable relayer;

    // Mapping from txHash => signed profit
    mapping(bytes32 => int256) public profits;

    event ProfitReported(bytes32 indexed txHash, int256 profit);

    constructor(address _relayer) {
        relayer = _relayer;
    }

    /**
     * Called by relayer to submit profit for a transaction.
     */
    function reportProfit(bytes32 txHash, int256 profit) external {
        require(msg.sender == relayer, "Not authorized relayer");
        require(profits[txHash] == 0, "Already reported");
        profits[txHash] = profit;

        emit ProfitReported(txHash, profit);
    }

    /**
     * Anyone (loan contract) can read verified profit.
     */
    function getVerifiedProfit(bytes32 txHash) external view returns (int256) {
        return profits[txHash];
    }

    function verifyProfit(
        address borrower,
        address token,
        uint256 amount,
        uint256 expiry,
        bytes32 nonce,
        bytes32 profitHash,
        bytes calldata signature
    ) external view override returns (bool) {
        bytes32 messageHash = keccak256(
            abi.encode(borrower, token, amount, expiry, nonce, profitHash)
        );
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(
            messageHash
        );
        return ECDSA.recover(ethSignedMessageHash, signature) == relayer;
    }
}
