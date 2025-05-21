// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import "openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";

contract FlashLoanModule {
    using SafeERC20 for IERC20;
    using ECDSA for bytes32;

    address public relayer;
    address public mizan;
    uint256 public profitSharePercentage = 10; // e.g., 10%

    mapping(bytes32 => bool) public usedNonces;

    event FlashLoanExecuted(
        address indexed borrower,
        address indexed token,
        uint256 amount,
        uint256 totalProfit,
        uint256 fee
    );

    constructor(address _relayer, address _mizan) {
        require(_relayer != address(0), "Invalid relayer address");
        require(_mizan != address(0), "Invalid mizan address");
        relayer = _relayer;
        mizan = _mizan;
    }

    modifier onlyMizan() {
        require(msg.sender == mizan, "Not mizan");
        _;
    }

    function updateRelayer(address _relayer) external onlyMizan {
        require(_relayer != address(0), "Invalid relayer address");
        relayer = _relayer;
    }

    function updateProfitSharePercentage(
        uint256 _percentage
    ) external onlyMizan {
        require(_percentage <= 100, "Invalid percentage");
        profitSharePercentage = _percentage;
    }

    struct ProfitMetadata {
        address taker;
        address token; // address(0) represents native ETH
    }

    struct FlashLoanMeta {
        ProfitMetadata[] profits;
        uint256 expiry;
        bytes32 nonce;
    }

    function requestFlashLoan(
        address loanToken,
        uint256 loanAmount,
        FlashLoanMeta calldata meta,
        bytes calldata signature
    ) external {
        require(block.timestamp <= meta.expiry, "Expired");
        require(!usedNonces[meta.nonce], "Nonce used");
        require(loanAmount > 0, "Invalid loan amount");
        require(meta.profits.length > 0, "No profit metadata");

        usedNonces[meta.nonce] = true;

        // Verify signature
        _verifySignature(loanToken, loanAmount, meta, signature);

        // Execute flash loan
        _executeFlashLoan(loanToken, loanAmount, meta);
    }

    function _verifySignature(
        address loanToken,
        uint256 loanAmount,
        FlashLoanMeta calldata meta,
        bytes calldata signature
    ) internal view {
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
        require(
            ECDSA.recover(ethSignedMessageHash, signature) == relayer,
            "Invalid signature"
        );
    }

    function _executeFlashLoan(
        address loanToken,
        uint256 loanAmount,
        FlashLoanMeta calldata meta
    ) internal {
        // Snapshot balances
        uint256[] memory beforeBalances = _snapshotBalances(meta.profits);

        // Send loan
        IERC20(loanToken).safeTransferFrom(mizan, msg.sender, loanAmount);

        // Execute strategy
        (bool ok, ) = msg.sender.call(
            abi.encodeWithSignature(
                "executeStrategy(address,uint256)",
                loanToken,
                loanAmount
            )
        );
        require(ok, "Strategy failed");

        // Require repayment
        IERC20(loanToken).safeTransferFrom(msg.sender, mizan, loanAmount);

        // Calculate and collect profits
        (uint256 totalProfit, uint256 totalFee) = _calculateAndCollectProfits(
            meta.profits,
            beforeBalances
        );

        require(totalProfit > 0, "No profit detected");

        emit FlashLoanExecuted(
            msg.sender,
            loanToken,
            loanAmount,
            totalProfit,
            totalFee
        );
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
        ProfitMetadata[] calldata profits,
        uint256[] memory beforeBalances
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
                        require(success, "ETH fee transfer failed");
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
            packed = abi.encodePacked(packed, data[i].taker, data[i].token);
        }
        return keccak256(packed);
    }

    // Allow contract to receive ETH
    receive() external payable {}
}
