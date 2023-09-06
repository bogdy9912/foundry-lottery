// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle, RaffleState} from "../../src/Raffle.sol";
import {Test, Vm, console} from "forge-std/Test.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract RaffleTest is Test {
    Raffle public raffle;
    HelperConfig public helperConfig;

    uint256 entraceFee;
    uint256 interval;
    VRFCoordinatorV2Interface vrfCoordinator;
    bytes32 gasLane;
    uint64 subscriptionID;
    uint32 callbackGasLimit;
    address linkToken;

    address public player = makeAddr("player");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.run();
        (
            entraceFee,
            interval,
            vrfCoordinator,
            gasLane,
            subscriptionID,
            callbackGasLimit,
            linkToken,

        ) = helperConfig.activeNetworkConfig();

        vm.deal(player, STARTING_USER_BALANCE);
        vm.label(player, "player Address");
    }

    function testRaffleInitializesInOpenState() external view {
        assert(raffle.raffleState() == RaffleState.OPEN);
    }

    function testIfEnterRaffleCanStartWithLessValueThanEntraceFee() public {
        vm.prank(player);
        vm.expectRevert(Raffle.Raffle_NotEnoughEthSent.selector);
        raffle.enterRaffle{value: entraceFee - 1}();
    }

    function testEnterRaffle() public {
        vm.startPrank(player);
        vm.expectEmit(true, false, false, false, address(raffle));
        emit Raffle_EnteredRaffle(player);
        raffle.enterRaffle{value: entraceFee}();
        vm.stopPrank();

        address[] memory players = raffle.players();
        assert(players.length == 1);
        assert(players[0] == player);
    }

    function testCantEnterWhenRaffleIsCalculating() public {
        vm.prank(player);
        raffle.enterRaffle{value: entraceFee}();

        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        raffle.performUpkeep("");

        vm.expectRevert(Raffle.Raffle_RaffleNotOpen.selector);
        vm.prank(player);
        raffle.enterRaffle{value: entraceFee}();
    }

    function testCheckUpkeepForNotEnoughTimePassed() public {
        vm.prank(player);
        raffle.enterRaffle{value: entraceFee}();

        vm.warp(block.timestamp + interval - 2); // change the time passed to be lower than the interval
        vm.roll(block.number + 1);

        // ensure that all the tested variables are as we expect
        assert(raffle.raffleState() == RaffleState.OPEN);
        assert(raffle.players().length > 0);
        assert(address(raffle).balance > 0);

        (bool upKeepNeeded, ) = raffle.checkUpkeed("");
        assert(!upKeepNeeded);
    }

    function testCheckUpkeepForNotRaffleStateOpen() public {
        vm.prank(player);
        raffle.enterRaffle{value: entraceFee}();

        // ensure that the timestamp is greater than the interval
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        raffle.pickWinner();

        // ensure that all the tested variables are as we expect
        assert(raffle.raffleState() == RaffleState.CALCULATING);
        assert(raffle.players().length > 0);
        assert(address(raffle).balance > 0);

        (bool upKeepNeeded, ) = raffle.checkUpkeed("");
        assert(!upKeepNeeded);
    }

    function testCheckUpkeepForEmptyBalanceInContract() public {
        vm.prank(player);
        raffle.enterRaffle{value: entraceFee}();
        // ensure that the timestamp is greater than the interval
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        //without any intervention we know that all the check variables are right

        vm.deal(address(raffle), 0); // set the balance of the contract to 0 to get false on upkeep

        (bool upKeepNeeded, ) = raffle.checkUpkeed("");
        assert(!upKeepNeeded);
    }

    function testCheckUpkeepForNoPlayers() public {
        vm.prank(player);

        //without any intervention we know that all the check variables are right
        assert(raffle.raffleState() == RaffleState.OPEN);
        vm.warp(block.timestamp + interval + 1);
        assert(block.timestamp - raffle.lastTimestamp() > raffle.interval());
        assert(raffle.players().length == 0);

        vm.deal(address(raffle), 1 ether);
        assert(address(raffle).balance > 0);

        (bool upKeepNeeded, ) = raffle.checkUpkeed("");
        assert(!upKeepNeeded);
    }

    function testIfUpkeepIsFalseThanRevertInPerformUpkeep() public {
        testCheckUpkeepForEmptyBalanceInContract();
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle_UpkeepNotNeeded.selector,
                0,
                1,
                RaffleState.OPEN
            )
        );
        raffle.performUpkeep("");
    }

    function testIfPickWinnerRevertsIfIntervalWasNotPassed() public {
        vm.prank(player);
        raffle.enterRaffle{value: entraceFee}();

        vm.expectRevert();
        raffle.pickWinner();
    }

    function testIfPerformUpkeepAndCheckLogs() public {
        vm.prank(player);
        raffle.enterRaffle{value: entraceFee}();
        // ensure that the timestamp is greater than the interval
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        assert(requestId > 0);
        bytes32 eventName = entries[1].topics[0];

        console.log("Topic[0] in an event: ");
        console.logBytes32(eventName);
        console.logBytes32(requestId);

        assert(eventName == keccak256("RequestedRaffleWinner(uint256)"));
        assert(entries[1].topics.length == 2);
    }

    function testEntraceFeeViewFunction() public view {
        assert(raffle.entraceFee() == 0.01 ether);
    }

    function testIntervalViewFunction() public view {
        assert(raffle.interval() == 30);
    }

    function testVrfCoordinatorViewFunction() public view {
        assert(raffle.vrfCoordinator() == vrfCoordinator);
    }

    modifier enterRaffleAndAddExtraTimeToPassTimestampCheck() {
        vm.prank(player);
        raffle.enterRaffle{value: 1 ether}();
        // ensure that the timestamp is greater than the interval
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        _;
    }

    modifier skipFork(){ // add this modifier on all cases where mock Coordinator is used
        if (block.number != 31337){
            return;
        }
        _;
    }

    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(
        uint256 randomRequestId
    ) public enterRaffleAndAddExtraTimeToPassTimestampCheck skipFork{
        vm.expectRevert("nonexistent request");
        VRFCoordinatorV2Mock(address(vrfCoordinator)).fulfillRandomWords(
            randomRequestId,
            address(raffle)
        );
    }

    function testFulfillRandomWordsPicksAWinnerResetsAndSendsMoney()
        public
        enterRaffleAndAddExtraTimeToPassTimestampCheck skipFork
    {
        // enter in lottery - MODIFIER
        // pass time - MODIFIER

        // perform upkeep
        // record events to get the request id
        vm.recordLogs();
        raffle.performUpkeep(""); // -> the request have been made
        assert(raffle.raffleState() == RaffleState.CALCULATING);

        Vm.Log[] memory entries = vm.getRecordedLogs();
        Vm.Log memory targetEvent = entries[1];
        assert(
            targetEvent.topics[0] == keccak256("RequestedRaffleWinner(uint256)")
        ); // check the signature of the emmited event to make sure that the topics[1] is requestId
        bytes32 requestId = targetEvent.topics[1];

        // return a random number in the name of chainlink
        // vm.deal(address(vrfCoordinator), 1 ether);
        VRFCoordinatorV2Mock(address(vrfCoordinator)).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );

        Vm.Log[] memory entriesAfterWinner = vm.getRecordedLogs();

        Vm.Log memory winnerEvent = entriesAfterWinner[0];

        assert(winnerEvent.topics[0] == keccak256("PickedWinner(address)"));
        address winner = abi.decode(winnerEvent.data, (address));

        assert(winner == player);
    }

    // expected events
    event Raffle_EnteredRaffle(address indexed participant);
    event RequestedRaffleWinner(uint256 indexed requestId);
}
