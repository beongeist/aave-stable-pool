// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseHook} from "v4-periphery/src/utils/BaseHook.sol";

import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import { BalanceDelta, toBalanceDelta } from "v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/src/types/BeforeSwapDelta.sol";
import { BeforeSwapDelta, toBeforeSwapDelta } from "v4-core/src/types/BeforeSwapDelta.sol";


import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {CurrencySettler} from "v4-core/test/utils/CurrencySettler.sol";
import { Currency, CurrencyLibrary } from "v4-core/src/types/Currency.sol";
import {SafeCast} from "v4-core/src/libraries/SafeCast.sol";

contract StableSwap is BaseHook {
    using SafeCast for uint256;
    using CurrencySettler for Currency;

    // uint256 public totalToken0ShareAmount = 1e18;
    // uint256 public totalToken1ShareAmount = 1e18;

    uint256 public totaltokenSharesAmount = 2e18;

    // mapping (address => uint256) token0Shares;
    // mapping (address => uint256) token1Shares;

    public mapping (address => uint256) tokenShares;

    address public token0;
    address public token1;
    address public aaveToken0;
    address public aaveToken1;

    IAaveV3Pool public aavePool;

    error OnlyHookLiquidity();
    error AlreadyInitialized();

    // Constructor to initialize the contract with a PoolManager
    constructor(
        IPoolManager _poolManager,
        address _aavePool
    ) BaseHook(_poolManager) {
        poolManager = _poolManager;
        aavePool    = IAaveV3Pool(_aavePool); 
    }

    function _afterInitialize(
        address sender, 
        PoolKey calldata key,
        uint160, 
        int24
    ) internal override returns (bytes4) {
        if (token0 != address(0) && token1 != address(0)) {
            revert AlreadyInitialized();
        }
        token0 = Currency.unwrap(key.currency0);
        token1 = Currency.unwrap(key.currency1);

        // Store the addresses of the corresponding aave tokens
        // For example, the address Aave's USDC token (aUSDC)
        aaveToken0 = aavePool.getReserveAToken(token0);
        aaveToken1 = aavePool.getReserveAToken(token1);

        // Approve Aave to take token0 and token1 from our hook at any time
        // This simplifies future interactions with Aave via deposit and withdraw functions
        IERC20(token0).approve(address(aavePool), type(uint256).max);
        IERC20(token1).approve(address(aavePool), type(uint256).max);

        uint256 initialToken0Amount = 1e6;
        uint256 initialToken1Amount = 1e6;

        // Transfer initial liquidity from deployer (msg.sender) to the contract
        // Then, also initialize the first LP shares
        // totalToken0ShareAmount is pre-initialized to 1
        
        // token0Shares[sender] = 1e18;
        // token1Shares[sender] = 1e18;
        tokenShares[sender] = 2e18;

        IERC20(token0).transferFrom(sender, address(this), initialToken0Amount);
        IERC20(token1).transferFrom(sender, address(this), initialToken1Amount);
        depositToAave(initialToken0Amount, initialToken1Amount);

        return BaseHook.afterInitialize.selector;
    }

    // before initialize should revert if token0 or token1 is not equal to the new pool tokens

    // Permissions for this hook
    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: true,
            beforeAddLiquidity: true,
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

        // Take the entire input amount from the user
        poolManager.take(inputCurrency, address(this), amount);
        
        // Withdraw equal amount from the Aave pool, and deposit the same amount in other token
        if (params.zeroForOne) {
            withdrawFromAave(0, amount);
            depositToAave(amount, 0);
        } else {
            withdrawFromAave(amount, 0);
            depositToAave(0, amount);
        }

        // Transfer equal output amount to the user        
        outputCurrency.settle(
            poolManager,
            address(this),
            amount,
            false
        );

        // Return the delta for the swap accounting
        int128 tokenAmount = amount.toInt128();

        BeforeSwapDelta returnDelta =
            isExactInput ? toBeforeSwapDelta(tokenAmount, -tokenAmount) : toBeforeSwapDelta(-tokenAmount, tokenAmount);

        return (BaseHook.beforeSwap.selector, returnDelta, 0);
    }

    /* Block native liquidity provision */
    function _beforeAddLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        bytes calldata hookData
    ) internal override onlyPoolManager returns (bytes4) {
        revert OnlyHookLiquidity();
    }

    /* Custom deposit */
    function deposit(uint256 token0Amount, uint256 token1Amount) public {
        (uint256 totalToken0Amount, uint256 totalToken1Amount) = getAaveTokenBalances();

        // // Handle minting new shares for token0
        // uint256 newToken0ShareAmount = totalToken0ShareAmount * token0Amount / totalToken0Amount;
        // totalToken0ShareAmount += newToken0ShareAmount;
        // token0Shares[msg.sender] += newToken0ShareAmount;

        // // Handle minting new shares for token1
        // uint256 newToken1ShareAmount = totalToken1ShareAmount * token1Amount / totalToken1Amount;
        // totalToken1ShareAmount += newToken1ShareAmount;
        // token1Shares[msg.sender] += newToken1ShareAmount;

        uint256 newTokenShareAmount = totaltokenSharesAmount * (token0Amount + token1Amount) / (totalToken0Amount + totalToken1Amount);
        totaltokenSharesAmount += newTokenShareAmount;
        tokenShares[msg.sender] += newTokenShareAmount;


        IERC20(token0).transferFrom(msg.sender, address(this), token0Amount);
        IERC20(token1).transferFrom(msg.sender, address(this), token1Amount);

        depositToAave(token0Amount, token1Amount);
    }

    /* Withdraw */
    function withdraw(uint256 token0Amount, uint256 token1Amount) public {
        (uint256 totalToken0Amount, uint256 totalToken1Amount) = getAaveTokenBalances();

        // // Handle burning shares for token0
        // uint256 newToken0ShareAmount = totalToken0ShareAmount * token0Amount / totalToken0Amount;
        // totalToken0ShareAmount -= newToken0ShareAmount;
        // token0Shares[msg.sender] -= newToken0ShareAmount;

        // // Handle burning shares for token1
        // uint256 newToken1ShareAmount = totalToken1ShareAmount * token1Amount / totalToken1Amount;
        // totalToken1ShareAmount -= newToken1ShareAmount;
        // token1Shares[msg.sender] -= newToken1ShareAmount;

        uint256 newTokenShareAmount = totaltokenSharesAmount * (token0Amount + token1Amount) / (totalToken0Amount + totalToken1Amount);
        totaltokenSharesAmount -= newTokenShareAmount;
        tokenShares[msg.sender] -= newTokenShareAmount;

        withdrawFromAave(token0Amount, token1Amount);

        IERC20(token0).transfer(msg.sender, token0Amount);
        IERC20(token1).transfer(msg.sender, token1Amount);
    }

    /* UTILITIES */
    function depositToAave(uint256 token0Amount, uint256 token1Amount) internal {
        if (token0Amount != 0)
            aavePool.deposit(token0, token0Amount, address(this), 0);
        if (token1Amount != 0)
            aavePool.deposit(token1, token1Amount, address(this), 0);
    }

    function withdrawFromAave(uint256 token0Amount, uint256 token1Amount) internal {
        // withdraw from aave to msg.sender
        if (token0Amount != 0)
            aavePool.withdraw(token0, token0Amount, address(this));
        if (token1Amount != 0)
            aavePool.withdraw(token1, token1Amount, address(this));
    }

    function getAaveTokenBalances() public view returns (uint256, uint256) {
        return (
            IERC20(aaveToken0).balanceOf(address(this)),
            IERC20(aaveToken1).balanceOf(address(this))
        );
    }
}

interface IAaveV3Pool {
    function deposit(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;

    function withdraw(address asset, uint256 amount, address to) external returns (uint256);
       
    function getReserveAToken(address asset) external returns (address); 
}