// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

/**
 * @title A simple Raffle Contract
 * @author bogdy9912
 * @notice This contract is for creating a sample raffle
 * @dev Implements Chainlink VRFv2
 */

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import {console} from "forge-std/Test.sol";

enum RaffleState {
    OPEN,
    CALCULATING
}

contract Raffle is VRFConsumerBaseV2 {
    uint256 private immutable _entraceFee;
    uint256 private immutable _interval;
    VRFCoordinatorV2Interface private immutable _vrfCoordinator;
    bytes32 private immutable _gasLane;
    uint64 private immutable _subscriptionID;
    uint32 private immutable _callbackGasLimit;
    address payable[] private _players;
    uint256 private _lastTimestamp;
    RaffleState private _raffleState;

    constructor(
        uint256 newEntraceFee,
        uint256 newInterval,
        VRFCoordinatorV2Interface newVrfCoordinator,
        bytes32 newGasLane,
        uint64 newSubscriptionID,
        uint32 newCallbackGasLimit
    ) VRFConsumerBaseV2(address(newVrfCoordinator)) {
        _entraceFee = newEntraceFee;
        _interval = newInterval;
        _lastTimestamp = block.timestamp;
        _vrfCoordinator = newVrfCoordinator;
        _gasLane = newGasLane;
        _subscriptionID = newSubscriptionID;
        _callbackGasLimit = newCallbackGasLimit;
        _raffleState = RaffleState.OPEN;
    }

    function enterRaffle() external payable {
        if (msg.value < _entraceFee) {
            revert Raffle_NotEnoughEthSent();
        }

        if (_raffleState != RaffleState.OPEN) {
            revert Raffle_RaffleNotOpen();
        }

        _players.push(payable(msg.sender));

        emit Raffle_EnteredRaffle(msg.sender);
    }

    function pickWinner() public {
        if (block.timestamp - _lastTimestamp < _interval) {
            revert();
        }

        _raffleState = RaffleState.CALCULATING;
        uint256 requestId = _vrfCoordinator.requestRandomWords(
            _gasLane,
            _subscriptionID,
            3,
            _callbackGasLimit,
            1
        );

        emit RequestedRaffleWinner(requestId);
    }

    

    function fulfillRandomWords(
        uint256,
        uint256[] memory randomWords
    ) internal override {
        uint256 indexOfWinner = randomWords[0] % _players.length;
        address payable winner = _players[indexOfWinner];
        _raffleState = RaffleState.OPEN;
        _players = new address payable[](0);
        _lastTimestamp = block.timestamp;

        (bool success, ) = winner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle_TransferFailed();
        }

        emit PickedWinner(winner);
        emit DebugEvent(winner);
    }

    function performUpkeep(bytes calldata) external {
        (bool needUpkeep, ) = checkUpkeed("");
        if (!needUpkeep) {
            revert Raffle_UpkeepNotNeeded(
                address(this).balance,
                _players.length,
                _raffleState
            );
        }
        pickWinner();
    }

    /** Getter Functions */

    /**
     * @dev This is the function that the Chainlink Automation nodes call to see if it's time to perform an upkeep.abi
     * The following should be true for this to return true:
     * 1. The time interval has passed btw raffle runs
     * 2. The raffle is in the OPEN state
     * 3. The contract has ETH (aka players) - it can have ETH and not players
     * 4. The subscription is funded with LINK
     */
    function checkUpkeed(
        bytes memory
    ) public view returns (bool upKeepNeeded, bytes memory) {
        if (block.timestamp - _lastTimestamp < _interval) {
            return (false, "0x0");
        }

        if (_raffleState != RaffleState.OPEN) {
            return (false, "0x0");
        }

        if (_players.length == 0) {
            return (false, "0x0");
        }

        if (address(this).balance == 0) {
            return (false, "0x0");
        }

        return (true, "0x0");
    }

    function entraceFee() external view returns (uint256) {
        return _entraceFee;
    }

    function interval() external view returns (uint256) {
        return _interval;
    }

    function vrfCoordinator()
        external
        view
        returns (VRFCoordinatorV2Interface)
    {
        return _vrfCoordinator;
    }

    function raffleState() external view returns (RaffleState) {
        return _raffleState;
    }

    function lastTimestamp() external view returns (uint256) {
        return _lastTimestamp;
    }

    function players() external view returns (address[] memory) {
        uint256 length = _players.length;
        address[] memory localPlayers = new address[](length);

        uint256 i;
        for (; i < length; ++i) {
            localPlayers[i] = _players[i];
        }
        return localPlayers;
    }

    /** Events */

    event Raffle_EnteredRaffle(address indexed participant);
    event PickedWinner(address payable winner);
    event RequestedRaffleWinner(uint256 indexed requestId);
    event DebugEvent(address);

    /** Errors */

    error Raffle_NotEnoughEthSent();


    
    error Raffle_TransferFailed();
    error Raffle_RaffleNotOpen();
    error Raffle_UpkeepNotNeeded(
        uint256 eth,
        uint256 nrOfPlayers,
        RaffleState raffleState
    );
}
