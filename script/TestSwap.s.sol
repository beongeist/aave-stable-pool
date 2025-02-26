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

import { StateLibrary } from "v4-core/src/libraries/StateLibrary.sol";
import { PoolKey } from "v4-core/src/types/PoolKey.sol";
import { Currency } from "v4-core/src/types/Currency.sol";
// import { IHooks } from "v4-core/src/interfaces/IHooks.sol";

import { StableSwap } from "../src/StableSwap.sol";

contract Example {
    using StateLibrary for PoolManager;

    UniversalRouter public immutable router;
    PoolManager public immutable poolManager;
    IPermit2 public immutable permit2;

    constructor(address _router, address _poolManager, address _permit2) {
        router = UniversalRouter(payable(_router));
        poolManager = PoolManager(_poolManager);
        permit2 = IPermit2(_permit2);
    }

    function approveTokenWithPermit2(
        address token,
        uint160 amount,
        uint48 expiration
    ) external {
        IERC20(token).approve(address(permit2), type(uint256).max);
        permit2.approve(token, address(router), amount, expiration);
    }

    function swapExactInputSingle(
        PoolKey calldata key, // PoolKey struct that identifies the v4 pool
        uint128 amountIn, // Exact amount of tokens to swap
        uint128 minAmountOut // Minimum amount of output tokens expected
    ) external returns (uint256 amountOut) {
        bytes memory commands = abi.encodePacked(uint8(Commands.V4_SWAP));
        bytes[] memory inputs = new bytes[](1);

        bytes memory actions = abi.encodePacked(
            uint8(Actions.SWAP_EXACT_IN_SINGLE),
            uint8(Actions.SETTLE_ALL),
            uint8(Actions.TAKE_ALL)
        );

        bytes[] memory params = new bytes[](3);
        params[0] = abi.encode(
            IV4Router.ExactInputSingleParams({
                poolKey: key,
                zeroForOne: true,
                amountIn: amountIn,
                amountOutMinimum: minAmountOut,
                hookData: bytes("")
            })
        );
        params[1] = abi.encode(key.currency0, amountIn);
        params[2] = abi.encode(key.currency1, minAmountOut);

        inputs[0] = abi.encode(actions, params);

        router.execute(commands, inputs, block.timestamp);

        amountOut = IERC20(Currency.unwrap(key.currency1)).balanceOf(address(this));
        IERC20(Currency.unwrap(key.currency1)).transfer(msg.sender, amountOut);
        require(amountOut >= minAmountOut, "Insufficient output amount");
        return amountOut;
    }
}

// Separate contract for the script
contract TestSwapScript is Script {
    function run() external {
        vm.startBroadcast();

        Example example = new Example(
            0x1095692A6237d83C6a72F3F5eFEdb9A670C49223, // router
            0x67366782805870060151383F4BbFF9daB53e5cD6, // poolManager
            0x000000000022D473030F116dDEE9F6B43aC78BA3  // permit2
        );

        address token0 = address(0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359);
        address token1 = address(0xc2132D05D31c914a87C6611C10748AEb04B58e8F);

        example.approveTokenWithPermit2(
            token0,
            type(uint160).max, // Max approval amount
            type(uint48).max   // Max expiration
        );

        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: 3000, // TODO: Replace with actual fee tier
            tickSpacing: 1, // TODO: Replace with actual tick spacing
            hooks: StableSwap(0xD9F47BAc4019FC199cb5D769CA2c2F501A999888) // TODO: Replace with actual hooks contract if needed
        });

        uint128 amountIn = 1e5;
        
        // Minimum 2 tokens with 18 decimals
        uint128 minAmountOut = 1e5;

        IERC20(token0).transfer(address(example), amountIn);

        uint256 actualAmountOut = example.swapExactInputSingle(
            key,
            amountIn,
            minAmountOut
        );
        
        vm.stopBroadcast();
    }
}