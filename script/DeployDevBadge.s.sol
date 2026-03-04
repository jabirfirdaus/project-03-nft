// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/DevBadge.sol";

contract DeployDevBadge is Script {
    function run() external returns (DevBadge) {
        address deployer = vm.envAddress("DEPLOYER_ADDRESS");
        string memory hiddenUri = "ipfs://bafybeihidden/hidden.json";

        vm.startBroadcast();
        DevBadge nft = new DevBadge(deployer, hiddenUri);
        vm.stopBroadcast();

        console.log("DevBadge deployed at:", address(nft));
        console.log("Owner:", deployer);
        console.log("Max Supply:", nft.MAX_SUPPLY());
        return nft;
    }
}