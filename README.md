# 🔗 Skillchain - Skill Reputation Protocol

> 🚀 A decentralized token-based endorsement system for validating and building skill reputation on the blockchain

## 📋 Overview

Skillchain is a **Clarity smart contract** that enables users to create skill profiles, endorse others' skills with tokens, and build verifiable reputation scores. Perfect for freelancers, professionals, and communities looking to establish trust through peer validation! 

## ✨ Key Features

- 🎯 **Skill Creation**: Users can create detailed skill profiles with categories
- 💰 **Token-Based Endorsements**: Stake SKILL tokens to endorse others' abilities  
- 🏆 **Reputation System**: Dynamic scoring based on endorsements and activity
- 🔒 **Anti-Gaming**: Prevents self-endorsement and duplicate endorsements
- 💎 **Reward Distribution**: Contract owners can distribute rewards to skilled users
- 📊 **Analytics**: Track endorsements, reputation, and category statistics

## 🛠️ Core Functions

### 👤 User Management
- `register-user` - Join the platform and receive 100 starter tokens
- `get-user` - View user profile and reputation stats

### 🎨 Skill Management  
- `create-skill` - Add a new skill with name, description, and category
- `get-skill` - Retrieve skill details and endorsement stats

### 💝 Endorsement System
- `endorse-skill` - Stake tokens to endorse someone's skill
- `withdraw-endorsement` - Remove endorsement and reclaim tokens
- `get-endorsement` - View specific endorsement details

### 📈 Reputation & Analytics
- `calculate-reputation-score` - Get comprehensive reputation score
- `get-skill-reputation` - View skill-specific reputation metrics
- `get-category-count` - See how many skills exist per category

## 🚀 Getting Started

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Stacks wallet for testing

### Installation

```bash
git clone <your-repo>
cd skillchain
```

```bash
clarinet console
```

### Initialize the Contract

```bash
(contract-call? .Skillchain initialize)
```

### Register as a User

```bash
(contract-call? .Skillchain register-user)
```

### Create Your First Skill

```bash
(contract-call? .Skillchain create-skill "JavaScript Development" "Expert in React, Node.js and modern JS frameworks" "Programming")
```

### Endorse Someone's Skill

```bash
(contract-call? .Skillchain endorse-skill u1 u50 "Amazing React developer!")
```

## 💡 Usage Examples

### 🔍 Check Your Token Balance
```clarity
(contract-call? .Skillchain get-token-balance tx-sender)
```

### 📊 View Skill Details
```clarity
(contract-call? .Skillchain get-skill u1)
```

### 🏅 Check Reputation Score
```clarity
(contract-call? .Skillchain calculate-reputation-score 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
```

## 🎮 Testing

```bash
clarinet test
```

```bash
clarinet check
```

## 🏗️ Architecture

- **SKILL Token**: ERC-20 compatible fungible token for endorsements
- **Skills Map**: Stores skill profiles with metadata and stats  
- **Users Map**: Tracks user reputation and activity metrics
- **Endorsements Map**: Records token stakes and endorsement messages
- **Categories Map**: Aggregates skills by category for discovery

## 🔐 Security Features

- ✅ Prevents self-endorsement
- ✅ Blocks duplicate endorsements  
- ✅ Validates token balances before staking
- ✅ Owner-only reward distribution
- ✅ Safe token transfers with error handling

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License.


