// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/Mizan.sol";
import "../src/test/BorrowerStrategy.sol";
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract TestToken is ERC20 {
    constructor() ERC20("Test Token", "TEST") {
        _mint(msg.sender, 1000000 * 10 ** 18);
    }
}

contract DeployScript is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy test tokens
        TestToken loanToken = new TestToken();
        TestToken profitToken = new TestToken();

        // Deploy Mizan with loan token as underlying
        Mizan mizan = new Mizan(address(loanToken), msg.sender);

        // Deploy BorrowerStrategy
        BorrowerStrategy borrower = new BorrowerStrategy(
            address(mizan),
            address(profitToken),
            1000 * 10 ** 18 // 1000 profit tokens
        );

        // Fund Mizan with tokens
        loanToken.transfer(address(mizan), 100000 * 10 ** 18);
        profitToken.transfer(address(mizan), 100000 * 10 ** 18);

        // Fund borrower with tokens
        loanToken.transfer(address(borrower), 1000 * 10 ** 18);
        profitToken.transfer(address(borrower), 1000 * 10 ** 18);

        vm.stopBroadcast();

        // Log addresses for .env file
        console2.log("LOAN_TOKEN_ADDRESS=%s", address(loanToken));
        console2.log("PROFIT_TOKEN_ADDRESS=%s", address(profitToken));
        console2.log("MIZAN_ADDRESS=%s", address(mizan));
        console2.log("BORROWER_ADDRESS=%s", address(borrower));
    }
}
