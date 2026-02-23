// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./Interactions.s.sol";

contract DeployRaffle is Script {
    function deployContract() public returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory networkConfig = helperConfig
            .getConfigByChainId();

        if (networkConfig.subscriptionId == 0) {
            // Create a new subscription
            networkConfig.subscriptionId = new CreateSubscription()
                .createSubscription(
                    networkConfig.vrfCoordinator,
                    networkConfig.account
                );
            console.log(
                "Subscription created with ID:",
                networkConfig.subscriptionId
            );

            // Fund the subscription
            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(
                networkConfig.vrfCoordinator,
                networkConfig.subscriptionId,
                networkConfig.link,
                networkConfig.account
            );
        }
        vm.startBroadcast(networkConfig.account);
        Raffle raffle = new Raffle(
            networkConfig.entranceFee,
            networkConfig.interval,
            networkConfig.vrfCoordinator,
            networkConfig.keyHash,
            networkConfig.subscriptionId,
            networkConfig.callbackGasLimit
        );
        vm.stopBroadcast();

        // Add the contract to the VRF
        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(
            address(raffle),
            networkConfig.vrfCoordinator,
            networkConfig.subscriptionId,
            networkConfig.account
        );

        return (raffle, helperConfig);
    }

    function run() public {
        deployContract();
    }
}
