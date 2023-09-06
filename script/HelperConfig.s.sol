// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {Script} from "forge-std/Script.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";

struct NetworkConfig {
    uint256 entraceFee;
    uint256 interval;
    VRFCoordinatorV2Interface vrfCoordinator;
    bytes32 gasLane;
    uint64 subscriptionId;
    uint32 callbackGasLimit;
    address linkAddress;
    uint256 deployerKey;
}

contract HelperConfig is Script {
    NetworkConfig public activeNetworkConfig;

    uint256 public constant DEFAULT_ANVIL_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = sepolia();
        } else if (block.chainid == 1) {
            activeNetworkConfig = mainnet();
        } else {
            activeNetworkConfig = local();
            // this should be for local anvil/ganache
        }
    }

    function sepolia()
        public
        view
        returns (NetworkConfig memory networkConfig)
    {
        networkConfig = NetworkConfig({
            entraceFee: 0.01 ether,
            interval: 30,
            vrfCoordinator: VRFCoordinatorV2Interface(
                0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625
            ),
            gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
            subscriptionId: 0, // pur subscription id
            callbackGasLimit: 500_000, // gas
            linkAddress: 0x779877A7B0D9E8603169DdbD7836e478b4624789, // LINK token address
            deployerKey: vm.envUint("PLAYGROUND_PRIVATE_KEY")
        });
    }

    function local() public returns (NetworkConfig memory networkConfig) {
        if (
            activeNetworkConfig.vrfCoordinator !=
            VRFCoordinatorV2Interface(address(0))
        ) {
            return activeNetworkConfig;
        }

        uint96 baseFee = 0.05 ether;
        uint96 gasPriceLink = 0.00001 ether;

        vm.startBroadcast();
        VRFCoordinatorV2Mock vrfCoordinatorMock = new VRFCoordinatorV2Mock(
            baseFee,
            gasPriceLink
        );
        LinkToken linkToken = new LinkToken();
        vm.stopBroadcast();

        networkConfig = NetworkConfig({
            entraceFee: 0.01 ether,
            interval: 30,
            vrfCoordinator: VRFCoordinatorV2Interface(vrfCoordinatorMock),
            gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
            subscriptionId: 0, // pur subscription id, our script will add this
            callbackGasLimit: 500_000, // gas
            linkAddress: address(linkToken),
            deployerKey: DEFAULT_ANVIL_KEY
        });
    }

    function mainnet()
        public
        view
        returns (NetworkConfig memory networkConfig)
    {
        networkConfig = NetworkConfig({
            entraceFee: 1,
            interval: 1,
            vrfCoordinator: VRFCoordinatorV2Interface(address(0)),
            gasLane: "",
            subscriptionId: 1,
            callbackGasLimit: 1,
            linkAddress: address(0),
            deployerKey: vm.envUint("PLAYGROUND_PRIVATE_KEY")
        });
    }
}
