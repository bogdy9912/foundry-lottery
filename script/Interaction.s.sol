// SPDX-Licanse-Identifier: MIT

pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script {
    function run() public returns (uint64) {
        return createSubscriptionUsingConfig();
    }

    function createSubscriptionUsingConfig() public returns (uint64) {
        HelperConfig helperConfig = new HelperConfig();
        (
            ,
            ,
            VRFCoordinatorV2Interface newVrfCoordinator,
            ,
            ,
            ,
            ,
uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();

        return createSubscription(address(newVrfCoordinator), deployerKey);
    }

    function createSubscription(
        address vrfCoordinator,
         uint256 deployerKey
    ) public returns (uint64 subId) {
        console.log("Creating subscription on ChainId: ", block.chainid);

        vm.startBroadcast(deployerKey);
        subId = VRFCoordinatorV2Mock(vrfCoordinator).createSubscription();
        vm.stopBroadcast();

        console.log("SubId is: ", subId);
    }
}

contract FundSubscription is Script {
    uint96 public constant FUND_AMOUNT = 3 ether;

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        (
            ,
            ,
            VRFCoordinatorV2Interface newVrfCoordinator,
            ,
            uint64 subscriptionId,
            ,
            address linkToken,
    uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();

        fundSubscription(address(newVrfCoordinator), subscriptionId, linkToken,deployerKey);
    }

    function fundSubscription(
        address vrfCoordinator,
        uint64 subId,
        address linkToken,
        uint256 deployerKey
    ) public {
        console.log("Fund subscription: ", subId);
        console.log("Using vrfCoordinator: ", address(vrfCoordinator));
        console.log("On ChainID: ", block.chainid);
        if (block.chainid == 31337) {
            vm.startBroadcast(deployerKey);
            VRFCoordinatorV2Mock(vrfCoordinator).fundSubscription(
                subId,
                FUND_AMOUNT
            );
            vm.stopBroadcast();
        } else {
            vm.startBroadcast(deployerKey);
            LinkToken(linkToken).transferAndCall(
                vrfCoordinator,
                FUND_AMOUNT,
                abi.encode(subId)
            );
            vm.stopBroadcast();
        }
    }

    function run() external {
        fundSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script {
    function addConsumer(
        address raffle,
        uint64 subId,
        address vrfCoordinator,
        uint256 deployerKey
    ) public {
        console.log("Adding consumer contract: ", raffle);
        console.log("Using VRFCoordinator: ", vrfCoordinator);
        console.log("in ChainId: ", block.chainid);
        console.log("PRIVATE KEY USED: ", deployerKey);
        vm.startBroadcast(deployerKey);
        VRFCoordinatorV2Mock(vrfCoordinator).addConsumer(subId, raffle);
        vm.stopBroadcast();
    }

    function addConsumerUsingConfig(address raffle) public {
        HelperConfig helperConfig = new HelperConfig();
        (
            ,
            ,
            VRFCoordinatorV2Interface newVrfCoordinator,
            ,
            uint64 subscriptionId,
            ,
            address linkToken,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();

        addConsumer(
            raffle,
            subscriptionId,
            address(newVrfCoordinator),
            deployerKey
        );
    }

    function run() external {
        address raffle = DevOpsTools.get_most_recent_deployment(
            "Raffle",
            block.chainid
        );
        addConsumerUsingConfig(raffle);
    }
}
