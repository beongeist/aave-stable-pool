// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {Constants} from "v4-core/src/../test/utils/Constants.sol";
import {StableSwap} from "../src/StableSwap.sol";
import {HookMiner} from "v4-periphery/src/utils/HookMiner.sol";
import {CurrencyLibrary, Currency} from "v4-core/src/types/Currency.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

/// @notice Mines the address and deploys the PointsHook.sol Hook contract
contract DeployInitializeHook is Script {
    function setUp() public {}

    function run() public {

        // hook contracts must have specific flags encoded in the address
        uint160 flags = uint160(
            Hooks.BEFORE_SWAP_FLAG | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG | Hooks.AFTER_INITIALIZE_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG
        );

        address CREATE2_DEPLOYER = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

        // Mine a salt that will produce a hook address with the correct flags
        bytes memory constructorArgs = abi.encode(IPoolManager(address(0x67366782805870060151383F4BbFF9daB53e5cD6)), address(0x794a61358D6845594F94dc1DB02A252b5b4814aD)); // poolmanager
        (address hookAddress, bytes32 salt) =
            HookMiner.find(CREATE2_DEPLOYER, flags, type(StableSwap).creationCode, constructorArgs);

        // Deploy the hook using CREATE2
        vm.broadcast();
        StableSwap ss = new StableSwap{salt: salt}(IPoolManager(address(0x67366782805870060151383F4BbFF9daB53e5cD6)), address(0x794a61358D6845594F94dc1DB02A252b5b4814aD));
        require(address(ss) == hookAddress, "StableSwap: hook address mismatch");

        IERC20 token0 = IERC20(0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359);
        IERC20 token1 = IERC20(0xc2132D05D31c914a87C6611C10748AEb04B58e8F);

        IPoolManager manager = IPoolManager(address(0x67366782805870060151383F4BbFF9daB53e5cD6));

        int24 tickSpacing = 1;
        PoolKey memory poolKey =
            PoolKey(Currency.wrap(address(token0)), Currency.wrap(address(token1)), 3000, tickSpacing, IHooks(hookAddress));
        vm.broadcast();
        token0.approve(address(hookAddress), 1e6);
        vm.broadcast();
        token1.approve(address(hookAddress), 1e6);
        vm.broadcast();
        manager.initialize(poolKey, Constants.SQRT_PRICE_1_1);
    }
}