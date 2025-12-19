// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Script.sol";
import "../src/QQQ.sol";

contract DeployQQQ is Script {
    function run() external returns (QQQ) {
        vm.startBroadcast();
        QQQ token = new QQQ();
        vm.stopBroadcast();

        console.log("QQQ token deployed to:", address(token));
        return token;
    }
}
