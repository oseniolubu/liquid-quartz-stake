# LiquidQuartz Staking Contract

A tiered staking smart contract built on the Stacks blockchain using Clarity. This contract provides users with a secure way to stake tokens and earn rewards based on their staking tier and duration.

## Overview

LiquidQuartz is an educational staking protocol that demonstrates key DeFi concepts including tiered rewards, lock periods, and reward distribution mechanisms. The contract is designed with security and transparency in mind.

## Features

### Tiered Reward System
The contract implements four distinct staking tiers, each with its own minimum stake requirement and reward rate:

- **Bronze Tier**: 1,000+ tokens staked → 5% reward rate
- **Silver Tier**: 5,000+ tokens staked → 7% reward rate
- **Gold Tier**: 10,000+ tokens staked → 10% reward rate
- **Platinum Tier**: 50,000+ tokens staked → 15% reward rate

Users are automatically assigned to the highest tier their stake amount qualifies for.

### Core Functionality

#### Staking
- Stake tokens to earn rewards based on your tier
- Minimum stake requirement: 100 tokens (configurable by admin)
- Lock period: 144 blocks (~1 day) before unstaking is allowed
- Automatic tier assignment based on stake amount

#### Reward Claims
- Claim accumulated rewards without unstaking
- Rewards calculated based on blocks staked and tier rate
- Continuous reward accrual while staked

#### Unstaking
- Withdraw your stake plus all accumulated rewards
- Must wait for lock period to complete
- Automatic reward calculation and distribution

#### Stake Management
- Increase your existing stake at any time
- Automatic tier upgrade if new total qualifies
- Track lifetime staking statistics

### Statistics & Tracking

The contract maintains comprehensive statistics:
- **Per-User Stats**: Lifetime staked amount, total rewards earned, stake count
- **Contract Stats**: Total staked, total stakers, rewards distributed, reward pool balance
- **Real-time Data**: Current stake info, tier status, claimable rewards

## Public Functions

### User Functions

```clarity
(stake (amount uint))
```
Stakes the specified amount of tokens. User must not have an active stake.

```clarity
(claim-rewards)
```
Claims all accumulated rewards without unstaking. Updates the last claim block.

```clarity
(unstake)
```
Withdraws the entire stake plus rewards. Must wait for lock period to complete.

```clarity
(increase-stake (additional-amount uint))
```
Adds more tokens to an existing stake. May upgrade your tier.

### Read-Only Functions

```clarity
(get-stake (user principal))
```
Returns stake information for a specific user including amount, blocks, tier, and total claimed.

```clarity
(calculate-rewards (user principal))
```
Calculates current claimable rewards for a user without executing a transaction.

```clarity
(get-tier-info (amount uint))
```
Returns tier information (tier number, rate, name) for a given stake amount.

```clarity
(can-unstake (user principal))
```
Checks if the lock period has elapsed for a user's stake.

```clarity
(get-contract-stats)
```
Returns comprehensive contract statistics including total staked, stakers, and reward pool.

```clarity
(get-staker-stats (user principal))
```
Returns lifetime statistics for a specific staker.

### Admin Functions

```clarity
(pause-contract)
```
Emergency pause to halt all staking operations. Owner only.

```clarity
(unpause-contract)
```
Resumes contract operations after pause. Owner only.

```clarity
(set-minimum-stake (new-minimum uint))
```
Updates the minimum stake requirement. Owner only.

```clarity
(add-to-reward-pool (amount uint))
```
Adds tokens to the reward pool for distribution. Owner only.

```clarity
(add-to-whitelist (user principal))
(remove-from-whitelist (user principal))
```
Manages whitelist for future access control features. Owner only.

## Error Codes

- `u100` - Owner only operation
- `u101` - Not enough balance
- `u102` - No stake found for user
- `u103` - User already has an active stake
- `u104` - Invalid amount (zero or negative)
- `u105` - Contract is paused
- `u106` - Insufficient rewards in pool
- `u107` - Minimum stake requirement not met
- `u108` - Lock period still active
- `u109` - Invalid tier

## Security Features

1. **Lock Period**: Prevents immediate unstaking, encouraging longer-term participation
2. **Pause Mechanism**: Emergency stop functionality for critical situations
3. **Reward Pool Validation**: Ensures sufficient rewards before distribution
4. **Single Stake Limit**: One active stake per user for simpler accounting
5. **Owner Controls**: Administrative functions restricted to contract owner

## Usage Example

### Staking Tokens
```clarity
;; Stake 10,000 tokens (qualifies for Gold tier)
(contract-call? .liquidquartz stake u10000)
```

### Checking Your Rewards
```clarity
;; Check how many rewards you've accumulated
(contract-call? .liquidquartz calculate-rewards tx-sender)
```

### Claiming Rewards
```clarity
;; Claim your rewards without unstaking
(contract-call? .liquidquartz claim-rewards)
```

### Increasing Your Stake
```clarity
;; Add 5,000 more tokens (might upgrade to Platinum)
(contract-call? .liquidquartz increase-stake u5000)
```

### Unstaking
```clarity
;; Withdraw everything after lock period
(contract-call? .liquidquartz unstake)
```
