// unit
// integration
// forked
// staging -> run test on a mainnet/testnet

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {Raffle} from "../../src/Raffle.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "../../script/Interaction.s.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract InteractionsTest is Test {
    Raffle public raffle;
    HelperConfig public helperConfig;
    VRFCoordinatorV2Interface vrfCoordinator;
    uint64 subscriptionID;
    address linkToken;
    uint256 deployerKey;

    function setUp() public {
        DeployRaffle deployRaffle = new DeployRaffle();

        (raffle, helperConfig) = deployRaffle.run();

        (
            ,
            ,
            vrfCoordinator,
            ,
            subscriptionID,
            ,
            linkToken,
            deployerKey
        ) = helperConfig.activeNetworkConfig();

        // after running the deploy script, subscriptionID = 1
        subscriptionID = 1;
    }

    function testDeployScript() public {
        // test if after running deploy script

        assertNotEq(address(raffle), address(0));
        // subscription exists

        (uint256 balance, , address owner, ) = VRFCoordinatorV2Mock(
            address(vrfCoordinator)
        ).getSubscription(subscriptionID);

        assert(owner == vm.addr(deployerKey));
        // subscription is funded
        assert(balance > 0);

        // consumer is added
        bool consumerAdded = VRFCoordinatorV2Mock(address(vrfCoordinator))
            .consumerIsAdded(subscriptionID, address(raffle));
        assertTrue(consumerAdded);
    }

    function testCreateSubscription() public {
        CreateSubscription createSubscription = new CreateSubscription();
        uint64 subId = createSubscription.createSubscription(
            address(vrfCoordinator),
            deployerKey
        );

        (, , address owner, ) = VRFCoordinatorV2Mock(address(vrfCoordinator))
            .getSubscription(subId);
        assert(owner == vm.addr(deployerKey));
    }

    function testCreateSubscriptionUsingConfig() public {
        CreateSubscription createSubscription = new CreateSubscription();
        uint64 subId = createSubscription.createSubscriptionUsingConfig();

        (, , address owner, ) = VRFCoordinatorV2Mock(address(vrfCoordinator))
            .getSubscription(subId);
        assert(owner == vm.addr(deployerKey));
    }

    function testFundSubscription() public {
        FundSubscription fundSubscription = new FundSubscription();
        fundSubscription.fundSubscription(
            address(vrfCoordinator),
            subscriptionID,
            linkToken,
            deployerKey
        );

        (uint256 balance, , address owner, ) = VRFCoordinatorV2Mock(
            address(vrfCoordinator)
        ).getSubscription(subscriptionID);

        assertNotEq(balance, 0);
        assertEq(owner, vm.addr(deployerKey));
    }

    function testAddConsumer() public {
        // check for existing consumer from the deployer script
        address deployer = vm.addr(deployerKey);
        bool hasConsumer = VRFCoordinatorV2Mock(address(vrfCoordinator))
            .consumerIsAdded(subscriptionID, address(raffle));

        if (hasConsumer) {
            // remove if it exists
            vm.prank(deployer);
            VRFCoordinatorV2Mock(address(vrfCoordinator)).removeConsumer(
                subscriptionID,
                address(raffle)
            );
        }

        bool consumerExists = VRFCoordinatorV2Mock(address(vrfCoordinator))
            .consumerIsAdded(subscriptionID, address(raffle));

        assertFalse(consumerExists);

        // use script for adding consumer
        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(
            address(raffle),
            subscriptionID,
            address(vrfCoordinator),
            deployerKey
        );

        // check if the script worked as expected
        bool consumerAdded = VRFCoordinatorV2Mock(address(vrfCoordinator))
            .consumerIsAdded(subscriptionID, address(raffle));
        assertTrue(consumerAdded);
    }
}
