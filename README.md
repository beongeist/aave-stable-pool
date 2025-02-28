# StableSwap App
### **Uniswap v4 Hooks with StableSwap 🦄**

##Try the App Here: [StableSwap](aave-stable-pool.vercel.app/)




StableSwap is a decentralized liquidity and swapping platform that integrates **Uniswap V4** with **Aave yield strategies**, enabling liquidity providers (LPs) to maximize their earnings while offering efficient swaps.

## Features

### Liquidity Provision & Yield Maximization

- **Deposit Liquidity**: Users can provide liquidity by depositing stablecoins (e.g., USDC and USDT).
- **Earn Aave Interest**: Deposited funds are partially allocated to Aave, generating additional yield.
- **Pool Fee Distribution**: LPs earn a share of swap fees from traders.
- **Dynamic Yield Boost**: LPs can earn **up to 10% of the pool’s accumulated interest from Aave**, proportional to their swap activity.

### Just-in-Time (JIT) Liquidity & Swaps

- **Efficient Token Swaps**: Users can swap stablecoins via Uniswap V4.
- **JIT Liquidity Mechanism**: Optimizes capital efficiency by providing liquidity only when swaps occur.
- **Low Slippage & Competitive Pricing**: Uses Uniswap's AMM model to minimize slippage.

### Advanced Withdrawal Mechanisms

- **Partial & Full Withdrawals**: Users can withdraw a custom percentage (10%, 25%, 50%, or 100%) of their funds.
- **Automated Share Calculation**: Ensures correct distribution of tokens based on LP shares.

### User-Friendly Dashboard & Real-Time Updates

- **Live Pool Data**: Displays pool balances, LP shares, and estimated earnings.
- **Seamless Web3 Integration**: Connects directly to MetaMask for secure interactions.
- **One-Click Permit2 Approval**: Simplifies token approvals for gas-efficient transactions.

## How LPs Earn More Yield

StableSwap enhances LP earnings through:

1. **Aave Yield Sharing**: LPs receive **up to 10% of Aave-generated interest**, proportional to their swap volume.
2. **Swap Fees**: Each trade generates fees, distributed among LPs.
3. **JIT Liquidity Efficiency**: Reduces impermanent loss by providing liquidity at optimal times.

## Getting Started

### Prerequisites

- Install [Node.js](https://nodejs.org/) and [npm](https://www.npmjs.com/)
- Install [MetaMask](https://metamask.io/) for Web3 connectivity

### Installation

```sh
# Clone the repository
git clone https://github.com/your-repo/aave-stable-pool.git

# Navigate into the project directory
cd aave-stable-pool

# Install dependencies
npm install

#Running the Application
npm run dev

#Get Started on Your own V4 hook with the same template!
[`Use this Template`](https://github.com/uniswapfoundation/v4-template/generate)


#License
This project is licensed under the MIT License.
