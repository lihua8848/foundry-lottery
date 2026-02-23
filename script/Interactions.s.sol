// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig, CodeConstants} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script, CodeConstants {
    function createSubscriptionUsingConfig() public returns (uint256, address) {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig
            .getConfigByChainId()
            .vrfCoordinator;
        uint256 subId = createSubscription(
            vrfCoordinator,
            helperConfig.getConfigByChainId().account
        );
        return (subId, vrfCoordinator);
    }

    function createSubscription(
        address vrfCoordinator,
        address account
    ) public returns (uint256) {
        vm.startBroadcast(account);
        uint256 subId = VRFCoordinatorV2_5Mock(vrfCoordinator)
            .createSubscription();
        vm.stopBroadcast();
        return subId;
    }

    function run() public {
        createSubscriptionUsingConfig();
    }
}

contract FundSubscription is Script, CodeConstants {
    uint256 public constant FUND_AMOUNT = 100 ether;

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig
            .getConfigByChainId()
            .vrfCoordinator;
        uint256 subId = helperConfig.getConfigByChainId().subscriptionId;
        address linkToken = helperConfig.getConfigByChainId().link;
        address account = helperConfig.getConfigByChainId().account;
        fundSubscription(vrfCoordinator, subId, linkToken, account);
    }

    function fundSubscription(
        address vrfCoordinator,
        uint256 subId,
        address linkToken,
        address account
    ) public {
        console.log("Funding subscription:", subId);
        console.log("Using vrfCoordinator:", vrfCoordinator);
        console.log("On ChainID:", block.chainid);
        if (block.chainid == LOCAL_CHAIN_ID) {
            vm.startBroadcast(account);
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(
                subId,
                FUND_AMOUNT
            );
            vm.stopBroadcast();
        } else {
            vm.startBroadcast();
            LinkToken(linkToken).transferAndCall(
                vrfCoordinator,
                FUND_AMOUNT,
                abi.encode(subId)
            );
            vm.stopBroadcast();
        }
    }

    function run() public {
        fundSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script {
    function addConsumerUsingConfig(
        address mostRecentlyDeployedContract
    ) public {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig
            .getConfigByChainId()
            .vrfCoordinator;
        uint256 subId = helperConfig.getConfigByChainId().subscriptionId;
        address account = helperConfig.getConfigByChainId().account;
        addConsumer(
            mostRecentlyDeployedContract,
            vrfCoordinator,
            subId,
            account
        );
    }

    function addConsumer(
        address contractToAddToVrf,
        address vrfCoordinator,
        uint256 subId,
        address account
    ) public {
        console.log("Adding consumer to:", contractToAddToVrf);
        console.log("Using vrfCoordinator:", vrfCoordinator);
        console.log("On ChainID:", block.chainid);
        vm.startBroadcast(account);
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(
            subId,
            contractToAddToVrf
        );
        vm.stopBroadcast();
    }

    function run() public {
        address mostRecentlyDeployedContract = DevOpsTools
            .get_most_recent_deployment("Raffle", block.chainid);
        addConsumerUsingConfig(mostRecentlyDeployedContract);
    }
}
