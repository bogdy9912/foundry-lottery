// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

/**
 * @title A simple Raffle Contract
 * @author bogdy9912
 * @notice This contract is for creating a sample raffle
 * @dev Implements Chainlink VRFv2
 */

contract Raffle {
    uint256 private immutable _entraceFee;
    uint256 private immutable _interval;

    address payable[] private _players;
    uint256 private _lastTimestamp;

    error Raffle_NotEnoughEthSent();

    event Raffle_EnteredRaffle();

    constructor(uint256 newEntraceFee, uint256 newInterval) {
        _entraceFee = newEntraceFee;
        _interval = newInterval;
        _lastTimestamp = block.timestamp;
    }

    function enterRaffle() external payable {
        if (msg.value < _entraceFee) {
            revert Raffle_NotEnoughEthSent();
        }

        _players.push(payable(msg.sender));

        emit Raffle_EnteredRaffle();
    }

    function pickWinner() external {
        if (block.timestamp - _lastTimestamp < _interval) {
            revert();
        }

        


    }

    /** Getter Functions */

    function entraceFee() external view returns (uint256) {
        return _entraceFee;
    }

    function interval() external view returns (uint256) {
        return _interval;
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
}
