// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/Mizan.sol";
import "../src/test/BorrowerStrategy.sol";
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import "openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";

contract TestToken is ERC20 {
    constructor() ERC20("Test Token", "TEST") {
        _mint(msg.sender, 1000000 * 10 ** 18);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract FlashLoanTest is Test {
    using ECDSA for bytes32;

    Mizan public mizan;
    BorrowerStrategy public borrower;
    TestToken public loanToken;
    TestToken public profitToken;
    address public relayer;
    uint256 public relayerPrivateKey;
    uint256 public constant PROFIT_AMOUNT = 1000 * 10 ** 18;
    uint256 public constant LOAN_AMOUNT = 10000 * 10 ** 18;

    function setUp() public {
        // Setup accounts
        relayerPrivateKey = 0xA11CE;
        relayer = vm.addr(relayerPrivateKey);

        // Deploy tokens
        loanToken = new TestToken();
        profitToken = new TestToken();

        // Deploy contracts
        mizan = new Mizan(address(loanToken), relayer);
        borrower = new BorrowerStrategy(
            address(mizan),
            address(profitToken),
            PROFIT_AMOUNT
        );

        // Fund contracts
        loanToken.mint(address(mizan), LOAN_AMOUNT * 2);
    }

    function executeStrategy(address token, uint256 amount) external {
        // Fund address as profit
        profitToken.mint(address(this), PROFIT_AMOUNT);

        // Approve Mizan to spend tokens on behalf of test contract
        IERC20(token).approve(address(mizan), amount);
        profitToken.approve(address(mizan), PROFIT_AMOUNT);
    }

    function test_FlashLoanSuccess() public {
        // Prepare flash loan metadata
        FlashLoan.ProfitMetadata[]
            memory profits = new FlashLoan.ProfitMetadata[](1);
        profits[0] = FlashLoan.ProfitMetadata({
            taker: address(this),
            token: address(profitToken)
        });

        FlashLoan.FlashLoanMeta memory meta = FlashLoan.FlashLoanMeta({
            profits: profits,
            expiry: block.timestamp + 1 hours,
            nonce: keccak256("test_nonce")
        });

        // Sign the message
        bytes32 messageHash = keccak256(
            abi.encode(
                address(loanToken),
                LOAN_AMOUNT,
                meta.expiry,
                meta.nonce,
                _hashProfitMetadata(profits)
            )
        );
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(
            messageHash
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            relayerPrivateKey,
            ethSignedMessageHash
        );
        bytes memory signature = abi.encodePacked(r, s, v);

        // Record initial balances
        uint256 initialLoanBalance = loanToken.balanceOf(address(mizan));
        uint256 initialProfitBalance = profitToken.balanceOf(address(this));

        // Execute flash loan
        mizan.requestFlashLoan(
            address(loanToken),
            LOAN_AMOUNT,
            meta,
            signature
        );

        // Verify balances
        assertEq(
            loanToken.balanceOf(address(mizan)),
            initialLoanBalance,
            "Loan not repaid"
        );
        assertEq(
            profitToken.balanceOf(address(this)),
            (initialProfitBalance + PROFIT_AMOUNT) - (PROFIT_AMOUNT / 10),
            "Profit not received"
        );
    }

    function test_FlashLoanInvalidSignature() public {
        // Prepare flash loan metadata
        FlashLoan.ProfitMetadata[]
            memory profits = new FlashLoan.ProfitMetadata[](1);
        profits[0] = FlashLoan.ProfitMetadata({
            taker: address(borrower),
            token: address(profitToken)
        });

        FlashLoan.FlashLoanMeta memory meta = FlashLoan.FlashLoanMeta({
            profits: profits,
            expiry: block.timestamp + 1 hours,
            nonce: keccak256("test_nonce")
        });

        // Sign with wrong private key
        bytes32 messageHash = keccak256(
            abi.encode(
                address(loanToken),
                LOAN_AMOUNT,
                meta.expiry,
                meta.nonce,
                _hashProfitMetadata(profits)
            )
        );
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(
            messageHash
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(0xB0B, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Should revert
        vm.expectRevert("Invalid signature");
        // borrower.requestFlashLoan(
        //     address(loanToken),
        //     LOAN_AMOUNT,
        //     meta,
        //     signature
        // );
        mizan.requestFlashLoan(
            address(loanToken),
            LOAN_AMOUNT,
            meta,
            signature
        );
    }

    function test_FlashLoanExpired() public {
        // Prepare flash loan metadata
        FlashLoan.ProfitMetadata[]
            memory profits = new FlashLoan.ProfitMetadata[](1);
        profits[0] = FlashLoan.ProfitMetadata({
            taker: address(borrower),
            token: address(profitToken)
        });

        FlashLoan.FlashLoanMeta memory meta = FlashLoan.FlashLoanMeta({
            profits: profits,
            expiry: block.timestamp - 1, // Expired
            nonce: keccak256("test_nonce")
        });

        // Sign the message
        bytes32 messageHash = keccak256(
            abi.encode(
                address(loanToken),
                LOAN_AMOUNT,
                meta.expiry,
                meta.nonce,
                _hashProfitMetadata(profits)
            )
        );
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(
            messageHash
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            relayerPrivateKey,
            ethSignedMessageHash
        );
        bytes memory signature = abi.encodePacked(r, s, v);

        // Should revert
        vm.expectRevert("Expired");
        mizan.requestFlashLoan(
            address(loanToken),
            LOAN_AMOUNT,
            meta,
            signature
        );
    }

    function test_FlashLoanReusedNonce() public {
        // Prepare flash loan metadata
        FlashLoan.ProfitMetadata[]
            memory profits = new FlashLoan.ProfitMetadata[](1);
        profits[0] = FlashLoan.ProfitMetadata({
            taker: address(this),
            token: address(profitToken)
        });

        FlashLoan.FlashLoanMeta memory meta = FlashLoan.FlashLoanMeta({
            profits: profits,
            expiry: block.timestamp + 1 hours,
            nonce: keccak256("test_nonce")
        });

        // Sign the message
        bytes32 messageHash = keccak256(
            abi.encode(
                address(loanToken),
                LOAN_AMOUNT,
                meta.expiry,
                meta.nonce,
                _hashProfitMetadata(profits)
            )
        );
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(
            messageHash
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            relayerPrivateKey,
            ethSignedMessageHash
        );
        bytes memory signature = abi.encodePacked(r, s, v);

        // Execute first flash loan
        mizan.requestFlashLoan(
            address(loanToken),
            LOAN_AMOUNT,
            meta,
            signature
        );

        // Try to reuse the same nonce
        vm.expectRevert("Nonce used");
        mizan.requestFlashLoan(
            address(loanToken),
            LOAN_AMOUNT,
            meta,
            signature
        );
    }

    function _hashProfitMetadata(
        FlashLoan.ProfitMetadata[] memory data
    ) internal pure returns (bytes32) {
        bytes memory packed;
        for (uint256 i = 0; i < data.length; i++) {
            packed = abi.encodePacked(packed, data[i].taker, data[i].token);
        }
        return keccak256(packed);
    }
}
