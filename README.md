# Senja Protocol

**The first permissionless lending and borrowing protocol built on the Kaia ecosystem.**

Senja is a decentralized lending protocol that enables users to supply liquidity, borrow assets, and manage collateralized positions across multiple blockchains through LayerZero's cross-chain infrastructure.

## 🌟 Features

### Core Functionality
- **Permissionless Lending & Borrowing**: Create lending pools for any supported token pair
- **Cross-Chain Operations**: Seamless asset transfers across different blockchains via LayerZero
- **Dynamic Interest Rates**: Adaptive interest rate models based on utilization
- **Flexible Collateral Management**: Support for multiple collateral types including native KAIA
- **Automated Liquidation**: MEV-friendly liquidation mechanisms with incentives
- **Position Management**: Individual position contracts for each user

### Advanced Features
- **Token Swapping**: Built-in DEX integration with DragonSwap for position management
- **Oracle Integration**: Real-time price feeds for accurate asset valuations
- **KAIA Buyback System**: 95% of revenue automatically buys KAIA to increase ecosystem TVL
- **Protocol Fee Management**: Automated fee collection and revenue distribution
- **Upgradeable Architecture**: UUPS proxy pattern for seamless upgrades
- **Access Control**: Role-based permissions for protocol management
- **Ecosystem Growth**: Self-sustaining mechanism that strengthens KAIA token value

## 🏗️ Architecture

### Core Contracts

#### LendingPoolFactory
- **Purpose**: Main factory contract for creating and managing lending pools
- **Features**: Pool creation, operator management, token data stream configuration
- **Upgradeable**: Yes (UUPS pattern)

#### LendingPool
- **Purpose**: Individual lending pool for specific token pairs
- **Features**: Supply/withdraw liquidity, borrow/repay assets, cross-chain transfers
- **Integration**: LayerZero for cross-chain operations

#### Position
- **Purpose**: Individual user position management
- **Features**: Collateral management, token swapping, repayment flexibility
- **Security**: Reentrancy protection, access control

#### Protocol
- **Purpose**: Protocol-level fee management and KAIA ecosystem buyback operations
- **Features**: Fee collection, automated WKAIA buybacks, revenue distribution
- **Integration**: DragonSwap for token swaps, 95% revenue → KAIA buyback
- **Ecosystem Impact**: Increases KAIA TVL and creates sustainable growth

### Supporting Contracts

- **IsHealthy**: Health check system for position validation
- **Liquidator**: Automated liquidation mechanisms
- **Oracle**: Price feed integration
- **LendingPoolRouter**: Interest rate calculations and pool management
- **PositionDeployer**: Factory for creating user positions

## 🚀 Getting Started

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Node.js and pnpm
- Git

### Installation

```bash
# Clone the repository
git clone https://github.com/your-org/senja-contract.git
cd senja-contract

# Install dependencies
forge install

# Install Node.js dependencies
pnpm install
```

### Build

```bash
forge build
```

### Test

```bash
# Run all tests
forge test

# Run specific test file
forge test --match-contract SenjaTest -vvv

# Run with gas reporting
forge test --gas-report
```

## 📋 Usage

### Creating a Lending Pool

```solidity
// Deploy a new lending pool
address lendingPool = lendingPoolFactory.createLendingPool(
    collateralToken,  // Address of collateral token
    borrowToken,      // Address of borrow token  
    ltv              // Loan-to-Value ratio (in basis points)
);
```

### Supplying Liquidity

```solidity
// Supply liquidity to earn interest
lendingPool.supplyLiquidity{value: amount}(user, amount);
```

### Borrowing Assets

```solidity
// Borrow assets (can be cross-chain)
lendingPool.borrowDebt{value: fee}(
    amount,                    // Amount to borrow
    destinationChainId,        // Target chain ID
    dstEid,                   // LayerZero endpoint ID
    addExecutorLzReceiveOption // Execution options
);
```

### Managing Positions

```solidity
// Supply collateral
lendingPool.supplyCollateral{value: amount}(amount, user);

// Withdraw collateral
lendingPool.withdrawCollateral(amount);

// Repay with selected token
lendingPool.repayWithSelectedToken(
    shares,           // Borrow shares to repay
    token,           // Token to use for repayment
    fromPosition,    // Use position tokens
    user,            // User address
    slippageTolerance // Slippage protection
);
```

## 🔧 Configuration

### Supported Networks

- **Kaia Mainnet**: Primary deployment network
- **Base**: Cross-chain support
- **HyperEVM**: Coming Soon
- **Optimism**: ComingSoon
- **Arbitrum**: Coming Soon

### Token Support

- **Native KAIA**: Wrapped as WKAIA for protocol operations
- **ERC-20 Tokens**: Any standard ERC-20 token
- **Cross-Chain Tokens**: LayerZero OFT tokens

### Oracle Integration

The protocol integrates with oracle providers:
- **Orakl Network**: Primary price feed provider

## 🛡️ Security

### Audit Status
- **Internal Review**: Completed
- **External Audit**: Pending
- **Bug Bounty**: Coming soon

### Security Features
- **Reentrancy Protection**: All critical functions protected
- **Access Control**: Role-based permissions
- **Slippage Protection**: Built-in slippage controls
- **Health Checks**: Automated position validation
- **Upgrade Safety**: UUPS pattern with proper authorization

## 📊 Protocol Economics

### Fee Structure
- **Protocol Fee**: 0.1% of borrow amount
- **Liquidation Incentive**: 5-10% (configurable)
- **Cross-Chain Fee**: LayerZero messaging fees

### Revenue Distribution & KAIA Buyback Mechanism
- **KAIA Buyback**: 95% of protocol revenue is used to buy KAIA tokens
- **Developer Fund**: 5% allocated for development and operational expenses

### KAIA Ecosystem Growth Strategy

The Senja protocol implements a unique buyback mechanism designed to strengthen the KAIA ecosystem:

#### Buyback Purpose
- **TVL Growth**: 95% of protocol revenue is used to purchase KAIA tokens, increasing the total value locked (TVL) in the KAIA ecosystem
- **Token Scarcity**: Regular buybacks create upward pressure on KAIA token price
- **Ecosystem Sustainability**: Reinvesting revenue back into the native token creates a sustainable growth cycle
- **Community Value**: Long-term holders benefit from the protocol's success through increased KAIA value

#### Buyback Mechanism
1. **Revenue Collection**: Protocol fees are collected in various tokens
2. **Token Swapping**: Collected tokens are swapped to WKAIA via DragonSwap
3. **Distribution**: 
   - 95% of WKAIA is locked in the protocol treasury (increasing ecosystem TVL)
   - 5% of WKAIA is available for developer operations
4. **Transparency**: All buyback transactions are recorded on-chain and publicly verifiable

#### Benefits for KAIA Ecosystem
- **Increased Demand**: Regular KAIA purchases create consistent demand
- **Reduced Supply**: Locked KAIA tokens reduce circulating supply
- **Ecosystem Value**: Higher KAIA value attracts more developers and users
- **Sustainable Growth**: Self-reinforcing mechanism that grows with protocol adoption

## 🔄 Cross-Chain Operations

Senja leverages LayerZero's infrastructure for seamless cross-chain operations:

### Supported Chains
- Kaia (Primary)
- Base
- HyperEVM (Coming Soon)
- Optimism (Coming Soon)
- Arbitrum (Coming Soon)

### Cross-Chain Features
- **Borrow on Any Chain**: Borrow assets on any supported network
- **Collateral Management**: Manage collateral across chains
- **Liquidation**: Cross-chain liquidation capabilities

## 🧪 Testing

### Test Coverage
- **Unit Tests**: Core functionality testing
- **Integration Tests**: Cross-contract interaction testing
- **Fuzz Testing**: Edge case validation
- **Gas Optimization**: Gas usage analysis

### Running Tests

```bash
# Run all tests
forge test

# Run with detailed output
forge test -vvv

# Run specific test
forge test --match-test testSupplyLiquidity

# Run with gas reporting
forge test --gas-report
```

## 📈 Monitoring

### Events
The protocol emits comprehensive events for monitoring:
- `SupplyLiquidity`: When users supply liquidity
- `WithdrawLiquidity`: When users withdraw liquidity
- `BorrowDebtCrosschain`: When users borrow assets
- `RepayByPosition`: When users repay loans
- `Liquidate`: When positions are liquidated

### Analytics
- **TVL Tracking**: Total Value Locked monitoring
- **Utilization Rates**: Pool utilization analytics
- **Interest Rates**: Dynamic rate tracking
- **Liquidation Events**: Liquidation monitoring

### Development Setup

```bash
# Install dependencies
forge install
pnpm install

# Run tests
forge test

# Format code
forge fmt

# Lint code
forge lint
```

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🔗 Links

- **Website**: https://senja-labs.vercel.app/
- **LINE Mini App**: https://liff.line.me/2008121905-vdPZYpL4
- **Dune Analytics**: https://dune.com/danuste/senja
- **GitHub Repo**: https://senja.gitbook.io/senja-docs
- **X (Twitter)**: https://x.com/SenjaLabs
- **Docs**: https://senja.gitbook.io/senja-docs
- **Demo Video**: https://www.youtube.com/watch?v=w0jvSg-ltNE
- **Pitch Deck**: https://docsend.com/view/xyti5eu6mt5jwava

## 📞 Support

For support and questions:
- **Email**: ghoza60@gmail.com (Smart Contract Engineer)

---

**Built with ❤️ for the Kaia ecosystem**
