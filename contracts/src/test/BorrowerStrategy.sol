// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "../lib/FlashLoan.sol";
import "openzeppelin-contracts/contracts/utils/Address.sol";

interface IMizan {
    function requestFlashLoan(
        address loanToken,
        uint256 loanAmount,
        FlashLoan.FlashLoanMeta calldata meta,
        bytes calldata signature
    ) external;
}

contract BorrowerStrategy {
    using SafeERC20 for IERC20;

    // Address of the Mizan contract
    IMizan public immutable mizan;

    // Address of the profit token (for testing)
    address public immutable profitToken;

    // Amount of profit to generate (for testing)
    uint256 public immutable profitAmount;

    event DummyEvent(string message);

    constructor(address _mizan, address _profitToken, uint256 _profitAmount) {
        require(_mizan != address(0), "Invalid mizan address");
        require(_profitToken != address(0), "Invalid profit token");
        require(_profitAmount > 0, "Invalid profit amount");

        mizan = IMizan(_mizan);
        profitToken = _profitToken;
        profitAmount = _profitAmount;
    }

    // This function will be called by the Mizan contract
    function executeStrategy(
        address loanToken,
        uint256 loanAmount
    ) external returns (bool) {
        require(msg.sender == address(mizan), "Only mizan");
        // emit a dummy event
        emit DummyEvent("executeStrategy");
        // Simulate arbitrage by minting profit tokens to this contract
        // In a real scenario, this would be the actual arbitrage logic
        // IERC20(profitToken).transfer(address(this), profitAmount);

        // Approve the loanToken to be transferred to the mizan contract
        IERC20(loanToken).approve(msg.sender, loanAmount);

        // Approve the profitToken to be transferred to the mizan contract
        IERC20(profitToken).approve(msg.sender, profitAmount);

        return true;
    }

    // Function to request a flash loan
    function requestFlashLoan(
        address loanToken,
        uint256 loanAmount,
        FlashLoan.FlashLoanMeta calldata meta,
        bytes calldata signature
    ) external {
        emit DummyEvent("requestFlashLoan");
        mizan.requestFlashLoan(loanToken, loanAmount, meta, signature);
    }
}
