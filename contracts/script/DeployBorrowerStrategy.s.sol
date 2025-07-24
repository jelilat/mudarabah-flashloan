// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/test/BorrowerStrategy.sol";

contract DeployBorrowerStrategy is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Set these to your actual deployed contract addresses and desired profit amount
        address mizan = vm.envAddress("MIZAN_ADDRESS");
        address profitToken = vm.envAddress("PROFIT_TOKEN_ADDRESS");
        uint256 profitAmount = 1000 * 10 ** 18;

        BorrowerStrategy borrower = new BorrowerStrategy(
            mizan,
            profitToken,
            profitAmount
        );

        vm.stopBroadcast();

        console2.log("BORROWER_STRATEGY_ADDRESS=%s", address(borrower));
    }
}
