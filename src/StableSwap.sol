// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseHook} from "v4-periphery/src/utils/BaseHook.sol";

import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/src/types/BeforeSwapDelta.sol";
import { BeforeSwapDelta, toBeforeSwapDelta } from "v4-core/src/types/BeforeSwapDelta.sol";


import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { Currency, CurrencyLibrary } from "v4-core/src/types/Currency.sol";
import {SafeCast} from "v4-core/src/libraries/SafeCast.sol";


contract StableSwap is BaseHook {
    using SafeCast for uint256;
    
    // Constructor to initialize the contract with a PoolManager
    constructor(IPoolManager _poolManager) BaseHook(_poolManager) {}

    // Permissions for this hook
    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: false,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: false,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: true,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    /**
     * A simplified 1:1 token swap.
     * It just transfers the tokens directly between the contract and the user.
     */
    function _beforeSwap(
        address, // Ignoring sender address
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        bytes calldata
    ) 
        internal
        override
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        // Determine the inbound and outbound tokens based on the swap direction
        (Currency inputCurrency, Currency outputCurrency) =
            params.zeroForOne ? (key.currency0, key.currency1) : (key.currency1, key.currency0);

        bool isExactInput = params.amountSpecified < 0;

        uint256 amount = isExactInput ? uint256(-params.amountSpecified) : uint256(params.amountSpecified);

        // Instead of minting/burning, transfer the tokens to/from the contract directly
        if (isExactInput) {
            // Transfer input token from the user to the contract
            IERC20(Currency.unwrap(inputCurrency)).transferFrom(msg.sender, address(this), amount);

            // Transfer output token from the contract to the user
            IERC20(Currency.unwrap(outputCurrency)).transfer(msg.sender, amount);
        } else {
            // Transfer input token from the contract to the user
            IERC20(Currency.unwrap(inputCurrency)).transfer(msg.sender, amount);

            // Transfer output token from the user to the contract
            IERC20(Currency.unwrap(outputCurrency)).transferFrom(msg.sender, address(this), amount);
        }

        // Return the delta for the swap accounting
        int128 tokenAmount = amount.toInt128();

        BeforeSwapDelta returnDelta =
            // isExactInput ? toBeforeSwapDelta(amount.toInt128(), -amount.toInt128()) : toBeforeSwapDelta(-amount.toInt128(), amount.toInt128());
            isExactInput ? toBeforeSwapDelta(tokenAmount, -tokenAmount) : toBeforeSwapDelta(-tokenAmount, tokenAmount);

        return (BaseHook.beforeSwap.selector, returnDelta, 0);
    }


}
