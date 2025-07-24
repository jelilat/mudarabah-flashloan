// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.19;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

interface IMizanDepositToken {
    function mint(address to, uint256 amount) external;
    function burn(address from, uint256 amount) external;
    function balanceOf(address account) external view returns (uint256);
}

interface IMizanLoanToken {
    function mint(address to, uint256 amount) external;
    function burn(address from, uint256 amount) external;
    function balanceOf(address account) external view returns (uint256);
}

library LongTermLoan {
    using SafeERC20 for IERC20;

    uint256 public constant MAX_LOAN_TO_COLLATERAL = 80; // 80% of collateral

    event LoanCreated(address indexed borrower, uint256 amount);
    event LoanRepaid(address indexed borrower, uint256 amount);

    function requestLoan(
        IMizanDepositToken depositToken,
        IMizanLoanToken loanToken,
        IERC20 underlyingToken,
        address borrower,
        uint256 amount
    ) external returns (bool) {
        // Calculate maximum loan based on deposit tokens
        uint256 totalStaked = depositToken.balanceOf(borrower);
        uint256 totalBorrowed = loanToken.balanceOf(borrower);
        require(totalStaked >= totalBorrowed, "Borrowed exceeds staked");

        // Calculate maximum borrowable amount based on LTV
        uint256 maxBorrowable = (totalStaked * MAX_LOAN_TO_COLLATERAL) / 100;
        require(
            amount + totalBorrowed <= maxBorrowable,
            "Insufficient collateral"
        );

        // Mint loan token and transfer underlying token
        loanToken.mint(borrower, amount);
        underlyingToken.safeTransfer(borrower, amount);

        emit LoanCreated(borrower, amount);
        return true;
    }

    function repayLoan(
        address mizan,
        IMizanLoanToken loanToken,
        IERC20 underlyingToken,
        address borrower,
        uint256 amount
    ) external returns (bool) {
        require(
            loanToken.balanceOf(borrower) >= amount,
            "Insufficient loan balance"
        );

        // Transfer repayment
        underlyingToken.safeTransferFrom(borrower, mizan, amount);

        // Burn loan token
        loanToken.burn(borrower, amount);

        emit LoanRepaid(borrower, amount);
        return true;
    }

    function getBorrowedAmount(
        IMizanLoanToken loanToken,
        address user
    ) external view returns (uint256) {
        return loanToken.balanceOf(user);
    }
}
