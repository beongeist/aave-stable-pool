pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/StableSwap.sol";

// import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {Currency} from "v4-core/src/types/Currency.sol";

import {Fixtures} from "./utils/Fixtures.sol";

import {Deployers} from "v4-core/test/utils/Deployers.sol";


contract StableSwapTest is Test, Deployers, Fixtures {
    StableSwap hook;

    uint256 tokenId;
    int24 tickLower;
    int24 tickUpper;

    function setUp() public {
        deployFreshManagerAndRouters();
        deployMintAndApprove2Currencies();

        deployAndApprovePosm(manager);

        // Deploy the hook to an address with the correct flags
        address flags = address(
            uint160(Hooks.BEFORE_SWAP_FLAG | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG)
                ^ (0x4444 << 144) // Namespace the hook to avoid collisions
        );
        bytes memory constructorArgs = abi.encode(manager); //Add all the necessary constructor arguments from the hook
        deployCodeTo("StableSwap.sol:StableSwap", constructorArgs, flags);
        hook = StableSwap(flags);

        // Create the pool
        key = PoolKey(currency0, currency1, 3000, 60, IHooks(hook));
        manager.initialize(key, SQRT_PRICE_1_1);

        // Seed liquidity
        IERC20(Currency.unwrap(currency0)).approve(address(hook), 1000e18);
        IERC20(Currency.unwrap(currency1)).approve(address(hook), 1000e18);


    }


}