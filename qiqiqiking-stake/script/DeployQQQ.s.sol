// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Script.sol";
import "../src/QQQKING.sol";

contract DeployQQQ is Script {
    function run() external returns (QQQKING) {
        vm.startBroadcast();
        QQQKING token = new QQQKING();
        vm.stopBroadcast();

        console.log("✅ QQQKING token deployed to:", address(token));
        return token;
    }
}
