// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.19;

interface IRelayerVerifier {
    function verifyProfit(
        address borrower,
        address token,
        uint256 amount,
        uint256 expiry,
        bytes32 nonce,
        bytes32 profitHash,
        bytes calldata signature
    ) external view returns (bool);
}
