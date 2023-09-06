//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script, console} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./Interaction.s.sol";

contract DeployRaffle is Script {
    function run() external returns (Raffle raffle, HelperConfig helperConfig) {
        console.log("CALLERRRRR:  ", msg.sender);
        console.log("Deploy Raffle Address is: ", address(this));
        // get the configuration for the network where the target contract is deployed
        helperConfig = new HelperConfig();
        (
            uint256 newEntraceFee,
            uint256 newInterval,
            VRFCoordinatorV2Interface newVrfCoordinator,
            bytes32 newGasLane,
            uint64 newSubscriptionID,
            uint32 newCallbackGasLimit,
            address linkToken,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();

        if (newSubscriptionID == 0) {
            // create subscription
            CreateSubscription createSubscription = new CreateSubscription();
            console.log(
                "CreateSubscription Address is: ",
                address(createSubscription)
            );
            newSubscriptionID = createSubscription.createSubscription(
                address(newVrfCoordinator),
                deployerKey
            );

            // Fund it
            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(
                address(newVrfCoordinator),
                newSubscriptionID,
                linkToken,
                deployerKey
            );
        }

        // Deploy the target contract
        vm.startBroadcast();
        raffle = new Raffle(
            newEntraceFee,
            newInterval,
            newVrfCoordinator,
            newGasLane,
            newSubscriptionID,
            newCallbackGasLimit
        );
        vm.stopBroadcast();

        AddConsumer addConsumer = new AddConsumer();
        console.log("AddConsumer Address is: ", address(addConsumer));
        addConsumer.addConsumer(
            address(raffle),
            newSubscriptionID,
            address(newVrfCoordinator),
            deployerKey
        );
    }
}
