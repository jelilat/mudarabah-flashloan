// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/Mizan.sol";
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract TestToken is ERC20 {
    constructor() ERC20("Test Token", "TEST") {
        _mint(msg.sender, 1000000 * 10 ** 18);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract LongTermLoanTest is Test {
    Mizan public mizan;
    TestToken public underlyingToken;
    address public relayer;
    uint256 public relayerPrivateKey;
    address public user;
    uint256 public constant STAKE_AMOUNT = 10000 * 10 ** 18;
    uint256 public constant BORROW_AMOUNT = 5000 * 10 ** 18;

    function setUp() public {
        // Setup accounts
        relayerPrivateKey = 0xA11CE;
        relayer = vm.addr(relayerPrivateKey);
        user = makeAddr("user");

        // Deploy tokens
        underlyingToken = new TestToken();

        // Deploy Mizan
        mizan = new Mizan(address(underlyingToken), relayer);

        // Fund user
        underlyingToken.mint(user, STAKE_AMOUNT * 2);
    }

    function test_StakeAndBorrow() public {
        uint256 initialUnderlyingBalance = underlyingToken.balanceOf(user);
        vm.startPrank(user);

        // Approve and stake
        underlyingToken.approve(address(mizan), STAKE_AMOUNT);
        mizan.stake(STAKE_AMOUNT);

        // Check deposit token balance
        uint256 depositBalance = mizan.getStakedAmount(user);
        assertEq(depositBalance, STAKE_AMOUNT, "Incorrect deposit balance");

        // Borrow
        mizan.requestLoan(BORROW_AMOUNT);

        // Check loan balance
        uint256 loanBalance = mizan.getBorrowedAmount(user);
        assertEq(loanBalance, BORROW_AMOUNT, "Incorrect loan balance");

        // Check underlying token balance
        uint256 underlyingBalance = underlyingToken.balanceOf(user);
        assertEq(
            underlyingBalance,
            initialUnderlyingBalance - BORROW_AMOUNT,
            "Incorrect underlying balance"
        );

        vm.stopPrank();
    }

    function test_RepayLoan() public {
        vm.startPrank(user);

        // Stake and borrow
        underlyingToken.approve(address(mizan), STAKE_AMOUNT);
        mizan.stake(STAKE_AMOUNT);
        mizan.requestLoan(BORROW_AMOUNT);

        // Record balances before repayment
        uint256 loanBalanceBefore = mizan.getBorrowedAmount(user);
        uint256 underlyingBalanceBefore = underlyingToken.balanceOf(user);

        // Repay loan
        underlyingToken.approve(address(mizan), BORROW_AMOUNT);
        mizan.repayLoan(BORROW_AMOUNT);

        // Check balances after repayment
        uint256 loanBalanceAfter = mizan.getBorrowedAmount(user);
        uint256 underlyingBalanceAfter = underlyingToken.balanceOf(user);

        assertEq(loanBalanceAfter, 0, "Loan not fully repaid");
        assertEq(
            underlyingBalanceAfter,
            underlyingBalanceBefore - BORROW_AMOUNT,
            "Incorrect underlying balance after repayment"
        );

        vm.stopPrank();
    }

    function test_UnstakeWithOutstandingLoan() public {
        vm.startPrank(user);

        // Stake and borrow
        underlyingToken.approve(address(mizan), STAKE_AMOUNT);
        mizan.stake(STAKE_AMOUNT);
        mizan.requestLoan(BORROW_AMOUNT);

        // Try to unstake with outstanding loan
        vm.expectRevert("Outstanding loans");
        mizan.unstake(STAKE_AMOUNT);

        vm.stopPrank();
    }

    function test_UnstakeAfterRepayment() public {
        vm.startPrank(user);

        // Stake and borrow
        underlyingToken.approve(address(mizan), STAKE_AMOUNT);
        mizan.stake(STAKE_AMOUNT);
        mizan.requestLoan(BORROW_AMOUNT);

        // Repay loan
        underlyingToken.approve(address(mizan), BORROW_AMOUNT);
        mizan.repayLoan(BORROW_AMOUNT);

        // Record balances before unstake
        uint256 depositBalanceBefore = mizan.getStakedAmount(user);
        uint256 underlyingBalanceBefore = underlyingToken.balanceOf(user);

        // Unstake
        mizan.unstake(STAKE_AMOUNT);

        // Check balances after unstake
        uint256 depositBalanceAfter = mizan.getStakedAmount(user);
        uint256 underlyingBalanceAfter = underlyingToken.balanceOf(user);

        assertEq(depositBalanceAfter, 0, "Deposit tokens not burned");
        assertEq(
            underlyingBalanceAfter,
            underlyingBalanceBefore + STAKE_AMOUNT,
            "Incorrect underlying balance after unstake"
        );

        vm.stopPrank();
    }

    function test_BorrowExceedsReserve() public {
        vm.startPrank(user);

        // Stake
        underlyingToken.approve(address(mizan), STAKE_AMOUNT);
        mizan.stake(STAKE_AMOUNT);

        // Try to borrow more than reserve
        uint256 maxBorrow = (STAKE_AMOUNT * mizan.LOAN_RESERVE_RATIO()) / 100;
        vm.expectRevert("Amount exceeds loan reserve");
        mizan.requestLoan(maxBorrow + 1);

        vm.stopPrank();
    }

    function test_GetPoolStats() public {
        vm.startPrank(user);

        // Stake
        underlyingToken.approve(address(mizan), STAKE_AMOUNT);
        mizan.stake(STAKE_AMOUNT);

        // Get pool stats
        (
            uint256 totalLiquidity,
            uint256 availableLoanReserve,
            uint256 totalLiquidityTokens
        ) = mizan.getPoolStats();

        assertEq(totalLiquidity, STAKE_AMOUNT, "Incorrect total liquidity");
        assertEq(
            availableLoanReserve,
            (STAKE_AMOUNT * mizan.LOAN_RESERVE_RATIO()) / 100,
            "Incorrect available loan reserve"
        );
        assertEq(
            totalLiquidityTokens,
            STAKE_AMOUNT,
            "Incorrect total liquidity tokens"
        );

        vm.stopPrank();
    }
}
