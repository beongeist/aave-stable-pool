// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {StableSwap} from "../src/StableSwap.sol";

contract EmergencyWithdraw is Script {
    address public constant STABLE_SWAP = 0x02eea0e5e1a9d5181c2c0d173D61CE7265f35888; //Deployed Contract

    function run() external {
        vm.startBroadcast();

        StableSwap stableSwap = StableSwap(STABLE_SWAP);

        stableSwap.emergencyWithdraw();

        vm.stopBroadcast();
    }
}
