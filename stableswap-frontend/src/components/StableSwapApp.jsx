// StableSwap Frontend using ethers.js
import { ethers } from 'ethers';
import { useState, useEffect } from 'react';

// ABI for the StableSwap contract (partial, based on the provided contract code)
const STABLESWAP_ABI = [
  // View functions
  "function token0() view returns (address)",
  "function token1() view returns (address)",
  "function aaveToken0() view returns (address)",
  "function aaveToken1() view returns (address)",
  "function tokenShares(address) view returns (uint256)",
  "function totaltokenSharesAmount() view returns (uint256)",
  "function getAaveTokenBalances() view returns (uint256, uint256)",
  
  // State-changing functions
  "function deposit(uint256 token0Amount, uint256 token1Amount)",
  "function withdraw(uint256 token0Amount, uint256 token1Amount)",
  
  // Events (to be defined if needed)
];

// Standard ERC20 ABI (for USDC and USDT interaction)
const ERC20_ABI = [
  "function balanceOf(address owner) view returns (uint256)",
  "function decimals() view returns (uint8)",
  "function symbol() view returns (string)",
  "function name() view returns (string)",
  "function approve(address spender, uint256 amount) returns (bool)",
  "function allowance(address owner, address spender) view returns (uint256)",
  "function transfer(address to, uint256 amount) returns (bool)",
  "function transferFrom(address from, address to, uint256 amount) returns (bool)"
];

// Uniswap V4 Quote ABI (simplified for this example)
const QUOTER_ABI = [
  "function quoteExactInputSingle(address tokenIn, address tokenOut, uint256 amountIn) view returns (uint256 amountOut)"
];

// Main StableSwap App Component
export default function StableSwapApp() {
  // Contract addresses (to be set based on deployment)
  const [stableSwapAddress, setStableSwapAddress] = useState("");
  const [quoterAddress, setQuoterAddress] = useState("");
  
  // State variables
  const [provider, setProvider] = useState(null);
  const [signer, setSigner] = useState(null);
  const [account, setAccount] = useState("");
  const [stableSwapContract, setStableSwapContract] = useState(null);
  const [token0Contract, setToken0Contract] = useState(null);
  const [token1Contract, setToken1Contract] = useState(null);
  const [token0Symbol, setToken0Symbol] = useState("");
  const [token1Symbol, setToken1Symbol] = useState("");
  const [token0Address, setToken0Address] = useState("");
  const [token1Address, setToken1Address] = useState("");
  const [token0Decimals, setToken0Decimals] = useState(6); // Default for USDC/USDT
  const [token1Decimals, setToken1Decimals] = useState(6); // Default for USDC/USDT
  const [userToken0Balance, setUserToken0Balance] = useState("0");
  const [userToken1Balance, setUserToken1Balance] = useState("0");
  const [userShareBalance, setUserShareBalance] = useState("0");
  const [totalShares, setTotalShares] = useState("0");
  const [poolToken0Balance, setPoolToken0Balance] = useState("0");
  const [poolToken1Balance, setPoolToken1Balance] = useState("0");
  const [isLoading, setIsLoading] = useState(false);
  const [transactionStatus, setTransactionStatus] = useState("");
  
  // Form state for user inputs
  const [depositToken0Amount, setDepositToken0Amount] = useState("");
  const [depositToken1Amount, setDepositToken1Amount] = useState("");
  const [withdrawToken0Amount, setWithdrawToken0Amount] = useState("");
  const [withdrawToken1Amount, setWithdrawToken1Amount] = useState("");
  const [swapFromToken, setSwapFromToken] = useState("token0");
  const [swapAmount, setSwapAmount] = useState("");
  const [swapQuote, setSwapQuote] = useState("0");
  
  // Initialize Web3 connection
  async function initializeWeb3() {

    try {
      // Check if MetaMask is installed
      if (window.ethereum) {

        const web3Provider = new ethers.providers.Web3Provider(window.ethereum);
        console.log("Web3 Provider Initialized:");
        
        // Request account access
        await window.ethereum.request({ method: 'eth_requestAccounts' });
        
        const web3Signer = web3Provider.getSigner();
        const userAddress = await web3Signer.getAddress();
        
        setProvider(web3Provider);
        setSigner(web3Signer);
        setAccount(userAddress);
        

        // Initialize contract instances
        const swapContract = new ethers.Contract(stableSwapAddress, STABLESWAP_ABI, web3Signer);
        setStableSwapContract(swapContract);
        console.log("StableSwap Contract Initialized:");
        
        // Get token addresses from contract
        const token0Addr = await swapContract.token0();
        const token1Addr = await swapContract.token1();
        
        console.log("Token Addresses Initialized:", token0Addr, token1Addr);    

        setToken0Address(token0Addr);
        setToken1Address(token1Addr);
        console.log("Token Addresses Initialized:");
        
        // Initialize token contracts
        const t0Contract = new ethers.Contract(token0Addr, ERC20_ABI, web3Signer);
        const t1Contract = new ethers.Contract(token1Addr, ERC20_ABI, web3Signer);
        console.log("Token Contracts Initialized:");
        
        setToken0Contract(t0Contract);
        setToken1Contract(t1Contract);
        console.log("Token Contracts Initialized:");
        
        // Get token information
        const t0Symbol = await t0Contract.symbol();
        const t1Symbol = await t1Contract.symbol();
        const t0Decimals = await t0Contract.decimals();
        const t1Decimals = await t1Contract.decimals();
        
        setToken0Symbol(t0Symbol);
        setToken1Symbol(t1Symbol);
        setToken0Decimals(t0Decimals);
        setToken1Decimals(t1Decimals);

        console.log("Token Information Initialized:");
        
        // Setup event listeners for MetaMask account changes
        window.ethereum.on('accountsChanged', (accounts) => {
          setAccount(accounts[0]);
          refreshBalances();
        });
        
        // Load initial data
        refreshBalances();
      } else {
        alert("Please install MetaMask to use this application");
      }
    } catch (error) {
      console.error("Error initializing Web3:", error);
      setTransactionStatus(`Error: ${error.message}`);
    }
  }
  
  // Refresh all balances and pool information
  async function refreshBalances() {
    if (!signer || !stableSwapContract || !token0Contract || !token1Contract) return;
    
    try {
      setIsLoading(true);
      const userAddress = await signer.getAddress();
      
      // Get user token balances
      const t0Balance = await token0Contract.balanceOf(userAddress);
      const t1Balance = await token1Contract.balanceOf(userAddress);
      
      // Format with proper decimals
      setUserToken0Balance(ethers.utils.formatUnits(t0Balance, token0Decimals));
      setUserToken1Balance(ethers.utils.formatUnits(t1Balance, token1Decimals));
      
      // Get pool information
      const [aaveToken0Balance, aaveToken1Balance] = await stableSwapContract.getAaveTokenBalances();
      setPoolToken0Balance(ethers.utils.formatUnits(aaveToken0Balance, token0Decimals));
      setPoolToken1Balance(ethers.utils.formatUnits(aaveToken1Balance, token1Decimals));
      
      // Get user's LP share balance
      const userShares = await stableSwapContract.tokenShares(userAddress);
      const totalSharesAmount = await stableSwapContract.totaltokenSharesAmount();
      
      setUserShareBalance(ethers.utils.formatEther(userShares));
      setTotalShares(ethers.utils.formatEther(totalSharesAmount));
      
      setIsLoading(false);
    } catch (error) {
      console.error("Error refreshing balances:", error);
      setTransactionStatus(`Error: ${error.message}`);
      setIsLoading(false);
    }
  }
  
  // Calculate the estimated output of a swap
  async function calculateSwapOutput() {
    if (!swapAmount || !provider || !token0Address || !token1Address) return;
    
    try {
      // For a simple implementation, we'll use a 0.05% fee as per the contract
      const amountIn = ethers.utils.parseUnits(
        swapAmount, 
        swapFromToken === "token0" ? token0Decimals : token1Decimals
      );
      
      // Calculate 0.05% fee as in the contract
      const amountOut = amountIn.mul(9995).div(10000);
      
      // Convert back to display units
      const formattedAmountOut = ethers.utils.formatUnits(
        amountOut,
        swapFromToken === "token0" ? token1Decimals : token0Decimals
      );
      
      setSwapQuote(formattedAmountOut);
    } catch (error) {
      console.error("Error calculating swap output:", error);
      setSwapQuote("Error");
    }
  }
  
  // Handle deposit of both tokens
  async function handleDeposit() {
    if (!stableSwapContract || !token0Contract || !token1Contract) {
      setTransactionStatus("Contracts not initialized");
      return;
    }
    
    try {
      setIsLoading(true);
      setTransactionStatus("Approving tokens...");
      
      const token0Amount = ethers.utils.parseUnits(depositToken0Amount || "0", token0Decimals);
      const token1Amount = ethers.utils.parseUnits(depositToken1Amount || "0", token1Decimals);
      
      // Check if either amount is zero
      if (token0Amount.isZero() && token1Amount.isZero()) {
        setTransactionStatus("Error: Please enter an amount to deposit");
        setIsLoading(false);
        return;
      }
      
      // Approve tokens if necessary
      if (!token0Amount.isZero()) {
        const token0Allowance = await token0Contract.allowance(account, stableSwapAddress);
        if (token0Allowance.lt(token0Amount)) {
          const approveTx = await token0Contract.approve(stableSwapAddress, token0Amount);
          setTransactionStatus(`Approving ${token0Symbol}... Transaction: ${approveTx.hash}`);
          await approveTx.wait();
        }
      }
      
      if (!token1Amount.isZero()) {
        const token1Allowance = await token1Contract.allowance(account, stableSwapAddress);
        if (token1Allowance.lt(token1Amount)) {
          const approveTx = await token1Contract.approve(stableSwapAddress, token1Amount);
          setTransactionStatus(`Approving ${token1Symbol}... Transaction: ${approveTx.hash}`);
          await approveTx.wait();
        }
      }
      
      // Deposit tokens
      setTransactionStatus("Depositing tokens...");
      const depositTx = await stableSwapContract.deposit(token0Amount, token1Amount);
      setTransactionStatus(`Deposit pending... Transaction: ${depositTx.hash}`);
      await depositTx.wait();
      
      setTransactionStatus(`Deposit successful!`);
      setDepositToken0Amount("");
      setDepositToken1Amount("");
      
      // Refresh balances
      await refreshBalances();
      setIsLoading(false);
    } catch (error) {
      console.error("Error during deposit:", error);
      setTransactionStatus(`Deposit failed: ${error.message}`);
      setIsLoading(false);
    }
  }
  
  // Handle withdrawal of tokens
  async function handleWithdraw() {
    if (!stableSwapContract) {
      setTransactionStatus("Contract not initialized");
      return;
    }
    
    try {
      setIsLoading(true);
      
      const token0Amount = ethers.utils.parseUnits(withdrawToken0Amount || "0", token0Decimals);
      const token1Amount = ethers.utils.parseUnits(withdrawToken1Amount || "0", token1Decimals);
      
      // Check if either amount is zero
      if (token0Amount.isZero() && token1Amount.isZero()) {
        setTransactionStatus("Error: Please enter an amount to withdraw");
        setIsLoading(false);
        return;
      }
      
      // Withdraw tokens
      setTransactionStatus("Withdrawing tokens...");
      const withdrawTx = await stableSwapContract.withdraw(token0Amount, token1Amount);
      setTransactionStatus(`Withdrawal pending... Transaction: ${withdrawTx.hash}`);
      await withdrawTx.wait();
      
      setTransactionStatus(`Withdrawal successful!`);
      setWithdrawToken0Amount("");
      setWithdrawToken1Amount("");
      
      // Refresh balances
      await refreshBalances();
      setIsLoading(false);
    } catch (error) {
      console.error("Error during withdrawal:", error);
      setTransactionStatus(`Withdrawal failed: ${error.message}`);
      setIsLoading(false);
    }
  }
  
  // Handle token swap
  async function handleSwap() {
    if (!provider || !signer) {
      setTransactionStatus("Web3 not initialized");
      return;
    }
    
    try {
      setIsLoading(true);
      
      // Get token addresses and contracts based on swap direction
      const fromTokenAddress = swapFromToken === "token0" ? token0Address : token1Address;
      const toTokenAddress = swapFromToken === "token0" ? token1Address : token0Address;
      const fromTokenContract = swapFromToken === "token0" ? token0Contract : token1Contract;
      const fromDecimals = swapFromToken === "token0" ? token0Decimals : token1Decimals;
      
      // Parse amount with proper decimals
      const amountIn = ethers.utils.parseUnits(swapAmount, fromDecimals);
      
      // Approve tokens for swap
      const allowance = await fromTokenContract.allowance(account, stableSwapAddress);
      if (allowance.lt(amountIn)) {
        setTransactionStatus("Approving tokens for swap...");
        const approveTx = await fromTokenContract.approve(stableSwapAddress, amountIn);
        await approveTx.wait();
      }
      
      // Construct swap parameters for Uniswap V4
      const swapParams = {
        zeroForOne: swapFromToken === "token0",
        amountSpecified: -amountIn.toString(), // Negative for exact input
        sqrtPriceLimitX96: 0 // No price limit
      };
      
      // For a direct swap using the hook's beforeSwap function, we need to interact with the PoolManager
      // This is a simplified example - in reality, we would need to use a router contract
      // that's designed to work with Uniswap V4 and our hook
      
      // For this example, we'll use a placeholder transaction
      setTransactionStatus("Swapping tokens...");
      // const swapTx = await routerContract.exactInputSingle(
      //   fromTokenAddress,
      //   toTokenAddress,
      //   amountIn,
      //   0, // Minimum out
      //   account // Recipient
      // );
      
      // Placeholder for actual swap transaction
      setTransactionStatus("Swap feature requires a custom Uniswap V4 router integration");
      setTransactionStatus("Please use the Uniswap interface connected to this pool for swaps");
      
      // Reset form
      setSwapAmount("");
      setSwapQuote("0");
      
      // Refresh balances after swap
      await refreshBalances();
      setIsLoading(false);
    } catch (error) {
      console.error("Error during swap:", error);
      setTransactionStatus(`Swap failed: ${error.message}`);
      setIsLoading(false);
    }
  }
  
  // Set up initial connection
  useEffect(() => {
    if (stableSwapAddress) {
      console.log("Initializing Web3 through useEffect...");  
      initializeWeb3(); //Audit this Logic TODO
    }
  }, [stableSwapAddress]);
  
  // Update swap quote when amount or direction changes
  useEffect(() => {
    if (swapAmount) {
      calculateSwapOutput();
    } else {
      setSwapQuote("0");
    }
  }, [swapAmount, swapFromToken]);

  // Refresh balances after all the async variables are set
  useEffect(() => {
    if (signer && stableSwapContract && token0Contract && token1Contract) {
      refreshBalances(); // Call refreshBalances once everything is initialized
    }
  }, [signer, stableSwapContract, token0Contract, token1Contract]);

  
  // Calculate user's share of the pool
  const userSharePercentage = totalShares && totalShares !== "0"
    ? (parseFloat(userShareBalance) / parseFloat(totalShares) * 100).toFixed(2)
    : "0";
  
  // Format user token values in the pool
  const userToken0InPool = totalShares && totalShares !== "0" && poolToken0Balance
    ? (parseFloat(poolToken0Balance) * parseFloat(userShareBalance) / parseFloat(totalShares)).toFixed(token0Decimals)
    : "0";
  
  const userToken1InPool = totalShares && totalShares !== "0" && poolToken1Balance
    ? (parseFloat(poolToken1Balance) * parseFloat(userShareBalance) / parseFloat(totalShares)).toFixed(token1Decimals)
    : "0";
  
  // UI for setting contract addresses (only shown when addresses not set)

  const [inputStableSwapAddress, setInputStableSwapAddress] = useState(""); // Store Input StableSwap Hook Address


  if (!stableSwapAddress) {
    return (
      <div className="container mx-auto p-4">
        <h1 className="text-2xl font-bold mb-4">StableSwap Configuration</h1>
        <div className="bg-gray-100 p-4 rounded-lg mb-4">
          <h2 className="text-lg font-semibold mb-2">Set Contract Addresses</h2>
          <div className="mb-3">
            <label className="block mb-1">StableSwap Contract Address:</label>
            <input
              className="w-full p-2 border rounded"
              value={inputStableSwapAddress} // Use the new input state here
              onChange={(e) => setInputStableSwapAddress(e.target.value)} 
              placeholder="0x..."
            />
          </div>
          <button
            className="bg-blue-500 text-white px-4 py-2 rounded hover:bg-blue-600"
            onClick={() => {
              if (ethers.utils.isAddress(inputStableSwapAddress)) {
                setStableSwapAddress(inputStableSwapAddress); // Update only when valid
                // initializeWeb3(); // Removed to avoid redundant calls. Already called when SwapAdress is update.^
              } else {
                alert("Please enter a valid Ethereum address");
              }
            }}
          >
            Initialize Application
          </button>
        </div>
      </div>
    );
  }
  
  // Main UI
  return (
    <div className="container mx-auto p-4">
      <h1 className="text-2xl font-bold mb-4">StableSwap - Uniswap V4 with Aave Yield</h1>
      
      {/* Connected Account Info */}
      <div className="bg-blue-50 p-4 rounded-lg mb-4">
        <div className="flex justify-between items-center">
          <div>
            <h2 className="font-semibold">Connected Account:</h2>
            <p className="text-sm">{account || "Not connected"}</p>
          </div>
          <button
            className="bg-blue-500 text-white px-3 py-1 rounded hover:bg-blue-600 text-sm"
            onClick={refreshBalances}
            disabled={isLoading}
          >
            {isLoading ? "Loading..." : "Refresh"}
          </button>
        </div>
      </div>
      
      {/* Transaction Status */}
      {transactionStatus && (
        <div className="bg-yellow-50 border border-yellow-200 p-3 rounded-lg mb-4">
          <p className="text-sm">{transactionStatus}</p>
        </div>
      )}
      
      {/* Pool Information */}
      <div className="bg-gray-50 p-4 rounded-lg mb-4">
        <h2 className="text-lg font-semibold mb-2">Pool Information</h2>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <h3 className="font-medium">Pool Balances:</h3>
            <p>{poolToken0Balance} {token0Symbol}</p>
            <p>{poolToken1Balance} {token1Symbol}</p>
          </div>
          <div>
            <h3 className="font-medium">Your Position:</h3>
            <p>
              {userShareBalance} shares ({userSharePercentage}% of pool)
            </p>
            <p>≈ {userToken0InPool} {token0Symbol}</p>
            <p>≈ {userToken1InPool} {token1Symbol}</p>
          </div>
        </div>
      </div>
      
      {/* User Balances */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
        <div className="bg-gray-50 p-4 rounded-lg">
          <h3 className="font-medium">Your {token0Symbol} Balance:</h3>
          <p className="text-xl font-semibold">{userToken0Balance}</p>
        </div>
        <div className="bg-gray-50 p-4 rounded-lg">
          <h3 className="font-medium">Your {token1Symbol} Balance:</h3>
          <p className="text-xl font-semibold">{userToken1Balance}</p>
        </div>
      </div>
      
      {/* Actions Section */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
        {/* Add Liquidity */}
        <div className="bg-white border p-4 rounded-lg shadow-sm">
          <h2 className="text-lg font-semibold mb-3">Add Liquidity</h2>
          <div className="mb-3">
            <label className="block mb-1">{token0Symbol} Amount:</label>
            <input
              className="w-full p-2 border rounded"
              type="number"
              value={depositToken0Amount}
              onChange={(e) => setDepositToken0Amount(e.target.value)}
              placeholder="0.0"
              min="0"
            />
          </div>
          <div className="mb-3">
            <label className="block mb-1">{token1Symbol} Amount:</label>
            <input
              className="w-full p-2 border rounded"
              type="number"
              value={depositToken1Amount}
              onChange={(e) => setDepositToken1Amount(e.target.value)}
              placeholder="0.0"
              min="0"
            />
          </div>
          <button
            className="w-full bg-green-500 text-white py-2 rounded hover:bg-green-600"
            onClick={handleDeposit}
            disabled={isLoading}
          >
            Deposit
          </button>
        </div>
        
        {/* Withdraw Liquidity */}
        <div className="bg-white border p-4 rounded-lg shadow-sm">
          <h2 className="text-lg font-semibold mb-3">Withdraw Liquidity</h2>
          <div className="mb-3">
            <label className="block mb-1">{token0Symbol} Amount:</label>
            <input
              className="w-full p-2 border rounded"
              type="number"
              value={withdrawToken0Amount}
              onChange={(e) => setWithdrawToken0Amount(e.target.value)}
              placeholder="0.0"
              min="0"
            />
          </div>
          <div className="mb-3">
            <label className="block mb-1">{token1Symbol} Amount:</label>
            <input
              className="w-full p-2 border rounded"
              type="number"
              value={withdrawToken1Amount}
              onChange={(e) => setWithdrawToken1Amount(e.target.value)}
              placeholder="0.0"
              min="0"
            />
          </div>
          <button
            className="w-full bg-red-500 text-white py-2 rounded hover:bg-red-600"
            onClick={handleWithdraw}
            disabled={isLoading}
          >
            Withdraw
          </button>
        </div>
        
        {/* Swap */}
        <div className="bg-white border p-4 rounded-lg shadow-sm">
          <h2 className="text-lg font-semibold mb-3">Swap</h2>
          <div className="mb-3">
            <label className="block mb-1">From:</label>
            <div className="flex">
              <select
                className="p-2 border rounded-l w-1/3"
                value={swapFromToken}
                onChange={(e) => setSwapFromToken(e.target.value)}
              >
                <option value="token0">{token0Symbol}</option>
                <option value="token1">{token1Symbol}</option>
              </select>
              <input
                className="w-2/3 p-2 border border-l-0 rounded-r"
                type="number"
                value={swapAmount}
                onChange={(e) => setSwapAmount(e.target.value)}
                placeholder="0.0"
                min="0"
              />
            </div>
          </div>
          <div className="mb-3">
            <label className="block mb-1">To:</label>
            <div className="p-2 border rounded bg-gray-50">
              {swapQuote} {swapFromToken === "token0" ? token1Symbol : token0Symbol}
            </div>
          </div>
          <button
            className="w-full bg-blue-500 text-white py-2 rounded hover:bg-blue-600"
            onClick={handleSwap}
            disabled={isLoading || !swapAmount}
          >
            Swap
          </button>
        </div>
      </div>
      
      {/* Footer with contract info */}
      <div className="mt-6 text-sm text-gray-500">
        <p>StableSwap Contract: {stableSwapAddress}</p>
        <p>Token0 ({token0Symbol}): {token0Address}</p>
        <p>Token1 ({token1Symbol}): {token1Address}</p>
      </div>
    </div>
  );
}