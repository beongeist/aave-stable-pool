// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Script.sol";
import { UniversalRouter } from "universal-router/contracts/UniversalRouter.sol";
import { Commands } from "universal-router/contracts/libraries/Commands.sol";
import { PoolManager } from "v4-core/src/PoolManager.sol";
import { IV4Router } from "v4-periphery/src/interfaces/IV4Router.sol";
import { Actions } from "v4-periphery/src/libraries/Actions.sol";
import { IPermit2 } from "permit2/src/interfaces/IPermit2.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { PoolKey } from "v4-core/src/types/PoolKey.sol";
import { Currency } from "v4-core/src/types/Currency.sol";
import { StableSwap } from "../src/StableSwap.sol";

contract TestSwapScript is Script {
    function run() external {
        vm.startBroadcast();

        // Define contract and token addresses
        address router = 0x1095692A6237d83C6a72F3F5eFEdb9A670C49223; // UniversalRouter
        address poolManager = 0x67366782805870060151383F4BbFF9daB53e5cD6; // PoolManager
        address permit2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3; // Permit2
        address token0 = 0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359; // USDC
        address token1 = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F; // USDT

        // Approve Permit2 to spend token0
        // IERC20(token0).approve(permit2, type(uint256).max);

        // Approve UniversalRouter via Permit2 to spend token0
        // IPermit2(permit2).approve(token0, router, type(uint160).max, type(uint48).max);

        // Prepare PoolKey for the Uniswap V4 pool
        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: 3000, // TODO: Replace with actual fee tier
            tickSpacing: 1, // TODO: Replace with actual tick spacing
            hooks: StableSwap(0xC0DB3c05eDA0a0ad64aE139003f6324Cd7E59888) // TODO: Replace with actual hooks contract if needed
        });

        // Define swap parameters
        uint128 amountIn = 1e5; // 0.1 USDC (since USDC has 6 decimals)
        uint128 minAmountOut = amountIn * 9995 / 10000; // ~0.09995 USDT, allowing 0.05% slippage

        // Prepare commands for UniversalRouter
        bytes memory commands = abi.encodePacked(uint8(Commands.V4_SWAP));
        
        // Prepare inputs array
        bytes[] memory inputs = new bytes[](1);

        // Encode actions sequence
        bytes memory actions = abi.encodePacked(
            uint8(Actions.SWAP_EXACT_IN_SINGLE), // Perform the exact input swap
            uint8(Actions.SETTLE_ALL),           // Settle all input tokens
            uint8(Actions.TAKE_ALL)             // Take all output tokens
        );

        // Encode parameters for each action
        bytes[] memory params = new bytes[](3);
        params[0] = abi.encode(
            IV4Router.ExactInputSingleParams({
                poolKey: key,
                zeroForOne: true,           // Swap token0 for token1
                amountIn: amountIn,
                amountOutMinimum: minAmountOut,
                hookData: bytes("")         // No hook data provided
            })
        );
        params[1] = abi.encode(key.currency0, amountIn);    // Settle amountIn of token0
        params[2] = abi.encode(key.currency1, minAmountOut); // Take minAmountOut of token1

        // Combine actions and params into inputs
        inputs[0] = abi.encode(actions, params);

        // Measure balance before swap
        uint256 balanceBefore = IERC20(token1).balanceOf(address(msg.sender));

        // Execute the swap
        UniversalRouter(payable(router)).execute(commands, inputs, block.timestamp * 2);

        // Measure balance after swap
        uint256 balanceAfter = IERC20(token1).balanceOf(address(msg.sender));
        uint256 amountOut = balanceAfter - balanceBefore;

        // Log and verify the output
        console.log("Amount out:", amountOut);
        require(amountOut >= minAmountOut, "Insufficient output amount");

        vm.stopBroadcast();
    }
}