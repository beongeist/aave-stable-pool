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
            uint160(Hooks.BEFORE_SWAP_FLAG | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG )
                ^ (0x4444 << 144) // Namespace the hook to avoid collisions also removed | Hooks.BEFORE_ADD_LIQUIDITY_FLAG
        );
        bytes memory constructorArgs = abi.encode(manager); //Add all the necessary constructor arguments from the hook
        deployCodeTo("StableSwap.sol:StableSwap", constructorArgs, flags);
        hook = StableSwap(flags);

        // Create the pool
        key = PoolKey(currency0, currency1, 3000, 60, IHooks(hook));
        manager.initialize(key, SQRT_PRICE_1_1);

        // Seed liquidity
        IERC20(Currency.unwrap(currency0)).approve(address(hook), type(uint256).max);
        IERC20(Currency.unwrap(currency1)).approve(address(hook), type(uint256).max);

        IERC20(Currency.unwrap(currency0)).transfer(address(hook), 1000e18);
        IERC20(Currency.unwrap(currency1)).transfer(address(hook), 1000e18);
    }

    function test_exactInputSwap() public {
        uint256 amount = 100e18;

        // Approve tokens for swap
        IERC20(Currency.unwrap(currency0)).approve(address(manager), amount);

        // Print balances before swap
        console.log("Contract balance0:", IERC20(Currency.unwrap(currency0)).balanceOf(address(hook)));
        console.log("Contract balance1:", IERC20(Currency.unwrap(currency1)).balanceOf(address(hook)));
        console.log("User balance0:", IERC20(Currency.unwrap(currency0)).balanceOf(address(this)));
        console.log("User balance1:", IERC20(Currency.unwrap(currency1)).balanceOf(address(this)));

        uint256 balance0Before = IERC20(Currency.unwrap(currency0)).balanceOf(address(this));
        uint256 balance1Before = IERC20(Currency.unwrap(currency1)).balanceOf(address(this));

        // Execute swap (zeroForOne = true, meaning selling currency0 for currency1)
        swap(key, true, -int256(amount), ZERO_BYTES);

        uint256 balance0After = IERC20(Currency.unwrap(currency0)).balanceOf(address(this));
        uint256 balance1After = IERC20(Currency.unwrap(currency1)).balanceOf(address(this));

        // Print balances after swap
        console.log("Contract balance0 after:", IERC20(Currency.unwrap(currency0)).balanceOf(address(hook)));
        console.log("Contract balance1 after:", IERC20(Currency.unwrap(currency1)).balanceOf(address(hook)));
        console.log("User balance0 after:", IERC20(Currency.unwrap(currency0)).balanceOf(address(this)));
        console.log("User balance1 after:", IERC20(Currency.unwrap(currency1)).balanceOf(address(this)));

        // Ensure we spent currency0 and received currency1
        assertEq(balance0Before - balance0After, amount);
        assertEq(balance1After - balance1Before, amount);
    }



}