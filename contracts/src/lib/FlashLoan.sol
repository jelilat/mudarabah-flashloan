// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.19;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import "openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";

library FlashLoan {
    using SafeERC20 for IERC20;
    using ECDSA for bytes32;

    struct ProfitMetadata {
        address taker;
        address token; // address(0) represents native ETH
    }

    struct FlashLoanMeta {
        ProfitMetadata[] profits;
        uint256 expiry;
        bytes32 nonce;
    }

    // Pure functions for hashing and encoding
    function encodeFlashLoanRequest(
        address loanToken,
        uint256 loanAmount,
        uint256 expiry,
        bytes32 nonce,
        bytes32 profitHash
    ) public pure returns (bytes memory) {
        return abi.encode(loanToken, loanAmount, expiry, nonce, profitHash);
    }

    function hashFlashLoanRequest(
        address loanToken,
        uint256 loanAmount,
        uint256 expiry,
        bytes32 nonce,
        bytes32 profitHash
    ) public pure returns (bytes32) {
        return
            keccak256(
                encodeFlashLoanRequest(
                    loanToken,
                    loanAmount,
                    expiry,
                    nonce,
                    profitHash
                )
            );
    }

    function encodeProfitMetadata(
        ProfitMetadata[] calldata data
    ) public pure returns (bytes memory) {
        bytes memory encoded;
        for (uint256 i = 0; i < data.length; i++) {
            encoded = abi.encode(encoded, data[i].taker, data[i].token);
        }
        return encoded;
    }

    function hashProfitMetadata(
        ProfitMetadata[] calldata data
    ) public pure returns (bytes32) {
        return keccak256(encodeProfitMetadata(data));
    }

    function borrow(
        address mizan,
        address relayer,
        uint256 profitSharePercentage,
        mapping(bytes32 => bool) storage usedNonces,
        address loanToken,
        uint256 loanAmount,
        FlashLoanMeta calldata meta,
        bytes calldata signature
    ) external returns (bool) {
        require(block.timestamp <= meta.expiry, "Expired");
        require(!usedNonces[meta.nonce], "Nonce used");
        require(loanAmount > 0, "Invalid loan amount");
        require(meta.profits.length > 0, "No profit metadata");

        usedNonces[meta.nonce] = true;

        // Verify signature
        if (
            !_verifySignature(loanToken, loanAmount, meta, signature, relayer)
        ) {
            revert("Invalid signature");
        }

        // Execute flash loan
        bool ok = _executeFlashLoan(
            mizan,
            loanToken,
            loanAmount,
            meta,
            profitSharePercentage
        );
        require(ok, "FlashLoan: strategy or profit failed");
        return true;
    }

    function _verifySignature(
        address loanToken,
        uint256 loanAmount,
        FlashLoanMeta calldata meta,
        bytes calldata signature,
        address relayer
    ) internal pure returns (bool) {
        bytes32 messageHash = keccak256(
            abi.encode(
                loanToken,
                loanAmount,
                meta.expiry,
                meta.nonce,
                _hashProfitMetadata(meta.profits)
            )
        );

        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(
            messageHash
        );
        return ECDSA.recover(ethSignedMessageHash, signature) == relayer;
    }

    function _executeFlashLoan(
        address mizan,
        address loanToken,
        uint256 loanAmount,
        FlashLoanMeta calldata meta,
        uint256 profitSharePercentage
    ) internal returns (bool) {
        // Snapshot balances
        uint256[] memory beforeBalances = _snapshotBalances(meta.profits);

        // Send loan - Mizan owns the tokens so use safeTransfer
        IERC20(loanToken).safeTransfer(msg.sender, loanAmount);

        // Execute strategy
        (bool ok, ) = msg.sender.call(
            abi.encodeWithSignature(
                "executeStrategy(address,uint256)",
                loanToken,
                loanAmount
            )
        );
        require(ok, "FlashLoan: executeStrategy failed");

        // Require repayment - borrower needs to approve Mizan
        IERC20(loanToken).safeTransferFrom(msg.sender, mizan, loanAmount);

        // Calculate and collect profits
        (uint256 totalProfit, ) = _calculateAndCollectProfits(
            mizan,
            meta.profits,
            beforeBalances,
            profitSharePercentage
        );

        require(totalProfit > 0, "FlashLoan: no profit detected");
        return true;
    }

    function _snapshotBalances(
        ProfitMetadata[] calldata profits
    ) internal view returns (uint256[] memory) {
        uint256[] memory beforeBalances = new uint256[](profits.length);
        for (uint256 i = 0; i < profits.length; i++) {
            require(profits[i].taker != address(0), "Invalid profit taker");
            if (profits[i].token == address(0)) {
                beforeBalances[i] = profits[i].taker.balance;
            } else {
                beforeBalances[i] = IERC20(profits[i].token).balanceOf(
                    profits[i].taker
                );
            }
        }
        return beforeBalances;
    }

    function _calculateAndCollectProfits(
        address mizan,
        ProfitMetadata[] calldata profits,
        uint256[] memory beforeBalances,
        uint256 profitSharePercentage
    ) internal returns (uint256 totalProfit, uint256 totalFee) {
        for (uint256 i = 0; i < profits.length; i++) {
            address taker = profits[i].taker;
            uint256 afterBal;

            if (profits[i].token == address(0)) {
                afterBal = taker.balance;
            } else {
                afterBal = IERC20(profits[i].token).balanceOf(taker);
            }

            if (afterBal >= beforeBalances[i]) {
                uint256 profit = afterBal - beforeBalances[i];
                totalProfit += profit;

                uint256 fee = (profit * profitSharePercentage) / 100;
                if (fee > 0) {
                    if (profits[i].token == address(0)) {
                        (bool success, ) = mizan.call{value: fee}("");
                        if (!success) return (0, 0);
                    } else {
                        IERC20(profits[i].token).safeTransferFrom(
                            taker,
                            mizan,
                            fee
                        );
                    }
                    totalFee += fee;
                }
            }
        }
    }

    function _hashProfitMetadata(
        ProfitMetadata[] calldata data
    ) internal pure returns (bytes32) {
        bytes memory packed;
        for (uint256 i = 0; i < data.length; i++) {
            packed = abi.encode(packed, data[i].taker, data[i].token);
        }
        return keccak256(packed);
    }
}
