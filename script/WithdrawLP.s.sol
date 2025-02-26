// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {StableSwap} from "../src/StableSwap.sol";

contract WithdrawLP is Script {
    address public constant STABLE_SWAP = 0x52f052d2411735287989461721f4B49A13d65888; //Deployed Contract
    address public constant USDC = 0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359; //USDC Address on Poly
    address public constant USDT = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F; // USDT address on Polygon
    uint256 public constant AMOUNT_USDC = 10e6; // Amount being withdrawn from the pool
    uint256 public constant AMOUNT_USDT = 10e6; // Amount being withdraw from the pool

    function run() external {
        vm.startBroadcast();

        StableSwap stableSwap = StableSwap(STABLE_SWAP);

        // Withdraw USDC and USDT
        stableSwap.withdraw(AMOUNT_USDC, AMOUNT_USDT);

        vm.stopBroadcast();
    }
}
