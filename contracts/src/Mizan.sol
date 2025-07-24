// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "./lib/LongTermLoan.sol";
import "./lib/FlashLoan.sol";

contract MizanDepositToken is ERC20, IMizanDepositToken {
    address public immutable mizan;

    constructor(address _mizan) ERC20("Mizan Deposit Token", "mDEPOSIT") {
        mizan = _mizan;
    }

    modifier onlyMizan() {
        require(msg.sender == mizan, "Not mizan");
        _;
    }

    function mint(address to, uint256 amount) external onlyMizan {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyMizan {
        _burn(from, amount);
    }

    function balanceOf(
        address account
    ) public view override(ERC20, IMizanDepositToken) returns (uint256) {
        return super.balanceOf(account);
    }
}

contract MizanLoanToken is ERC20, IMizanLoanToken {
    address public immutable mizan;

    constructor(address _mizan) ERC20("Mizan Loan Token", "mLOAN") {
        mizan = _mizan;
    }

    modifier onlyMizan() {
        require(msg.sender == mizan, "Not mizan");
        _;
    }

    function mint(address to, uint256 amount) external onlyMizan {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyMizan {
        _burn(from, amount);
    }

    function balanceOf(
        address account
    ) public view override(ERC20, IMizanLoanToken) returns (uint256) {
        return super.balanceOf(account);
    }
}

contract Mizan is Ownable {
    using SafeERC20 for IERC20;

    // Events
    event Staked(address indexed user, uint256 amount, uint256 depositTokens);
    event Unstaked(address indexed user, uint256 amount, uint256 depositTokens);

    // Token interfaces
    IERC20 public underlyingToken;
    MizanDepositToken public depositToken;
    MizanLoanToken public loanToken;

    // Flash loan state
    address public relayer;
    uint256 public profitSharePercentage = 10;
    mapping(bytes32 => bool) public usedNonces;

    // Pool accounting
    uint256 public totalLiquidity;
    uint256 public totalLiquidityTokens;
    uint256 public constant LOAN_RESERVE_RATIO = 50; // 50% of total liquidity

    constructor(
        address _underlyingToken,
        address _relayer
    ) Ownable(msg.sender) {
        require(_underlyingToken != address(0), "Invalid underlying token");
        require(_relayer != address(0), "Invalid relayer address");

        // Deploy tokens
        depositToken = new MizanDepositToken(address(this));
        loanToken = new MizanLoanToken(address(this));

        underlyingToken = IERC20(_underlyingToken);
        relayer = _relayer;
    }

    function stake(uint256 amount) external {
        require(amount > 0, "Invalid amount");

        // Calculate deposit tokens to mint based on pool ratio
        uint256 depositTokens;
        if (totalLiquidity == 0) {
            depositTokens = amount;
        } else {
            depositTokens = (amount * totalLiquidityTokens) / totalLiquidity;
        }

        // Update pool accounting
        totalLiquidity += amount;
        totalLiquidityTokens += depositTokens;

        // Transfer tokens and mint deposit tokens
        underlyingToken.safeTransferFrom(msg.sender, address(this), amount);
        depositToken.mint(msg.sender, depositTokens);

        emit Staked(msg.sender, amount, depositTokens);
    }

    function unstake(uint256 depositTokenAmount) external {
        require(depositTokenAmount > 0, "Invalid amount");
        require(
            depositToken.balanceOf(msg.sender) >= depositTokenAmount,
            "Insufficient deposit tokens"
        );

        // Check for outstanding loans
        require(
            LongTermLoan.getBorrowedAmount(
                IMizanLoanToken(address(loanToken)),
                msg.sender
            ) == 0,
            "Outstanding loans"
        );

        // Calculate withdrawal amount based on pool ratio
        uint256 withdrawAmount = (depositTokenAmount * totalLiquidity) /
            totalLiquidityTokens;
        require(withdrawAmount > 0, "Zero withdrawal amount");

        // Update pool accounting
        totalLiquidity -= withdrawAmount;
        totalLiquidityTokens -= depositTokenAmount;

        // Burn deposit tokens and transfer underlying tokens
        depositToken.burn(msg.sender, depositTokenAmount);
        underlyingToken.safeTransfer(msg.sender, withdrawAmount);

        emit Unstaked(msg.sender, withdrawAmount, depositTokenAmount);
    }

    function requestLoan(uint256 amount) external {
        require(amount > 0, "Invalid amount");

        // Calculate available loan reserve
        uint256 availableLoanReserve = (totalLiquidity * LOAN_RESERVE_RATIO) /
            100;
        uint256 currentLoans = loanToken.totalSupply();
        require(
            amount <= availableLoanReserve - currentLoans,
            "Amount exceeds loan reserve"
        );

        // Disburse loan
        require(
            LongTermLoan.requestLoan(
                IMizanDepositToken(address(depositToken)),
                IMizanLoanToken(address(loanToken)),
                underlyingToken,
                msg.sender,
                amount
            ),
            "Loan request failed"
        );
    }

    function repayLoan(uint256 amount) external {
        require(amount > 0, "Invalid amount");
        require(
            LongTermLoan.repayLoan(
                address(this),
                IMizanLoanToken(address(loanToken)),
                underlyingToken,
                msg.sender,
                amount
            ),
            "Loan repayment failed"
        );
    }

    function requestFlashLoan(
        address _loanToken,
        uint256 loanAmount,
        FlashLoan.FlashLoanMeta calldata meta,
        bytes calldata signature
    ) external {
        require(_loanToken != address(0), "Invalid loan token");
        require(loanAmount > 0, "Invalid loan amount");
        require(meta.profits.length > 0, "No profit metadata");
        require(block.timestamp <= meta.expiry, "Expired");
        require(!usedNonces[meta.nonce], "Nonce used");
        
        bool success = FlashLoan.borrow(
            address(this),
            relayer,
            profitSharePercentage,
            usedNonces,
            _loanToken,
            loanAmount,
            meta,
            signature
        );
        require(success, "FlashLoan: execution failed");
    }

    // Pure functions for hashing and encoding
    function hashProfitMetadata(
        FlashLoan.ProfitMetadata[] calldata data
    ) external pure returns (bytes32) {
        return FlashLoan.hashProfitMetadata(data);
    }

    function hashFlashLoanRequest(
        address loanToken,
        uint256 loanAmount,
        uint256 expiry,
        bytes32 nonce,
        bytes32 profitHash
    ) external pure returns (bytes32) {
        return
            FlashLoan.hashFlashLoanRequest(
                loanToken,
                loanAmount,
                expiry,
                nonce,
                profitHash
            );
    }

    function updateRelayer(address _relayer) external onlyOwner {
        require(_relayer != address(0), "Invalid relayer address");
        relayer = _relayer;
    }

    function updateProfitSharePercentage(
        uint256 _percentage
    ) external onlyOwner {
        require(_percentage <= 100, "Invalid percentage");
        profitSharePercentage = _percentage;
    }

    // View functions
    function getStakedAmount(address user) external view returns (uint256) {
        return depositToken.balanceOf(user);
    }

    function getBorrowedAmount(address user) external view returns (uint256) {
        return
            LongTermLoan.getBorrowedAmount(
                IMizanLoanToken(address(loanToken)),
                user
            );
    }

    function getPoolStats()
        external
        view
        returns (
            uint256 _totalLiquidity,
            uint256 _availableLoanReserve,
            uint256 _totalLiquidityTokens
        )
    {
        uint256 availableLoanReserve = (totalLiquidity * LOAN_RESERVE_RATIO) /
            100;
        uint256 currentLoans = loanToken.totalSupply();
        return (
            totalLiquidity,
            availableLoanReserve - currentLoans,
            totalLiquidityTokens
        );
    }

    // Allow contract to receive ETH
    receive() external payable {}
}
