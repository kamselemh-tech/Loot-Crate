# Fortune Chest Smart Contract

A comprehensive loot box implementation on the Stacks blockchain featuring multiple tiers, robust error handling, and administrative controls.

## Overview

Fortune Chest is a smart contract that implements a loot box system with four different tiers of rarity. Users can purchase loot boxes with STX tokens, open them to receive random items, and manage their inventory. The contract includes administrative functions for managing prices, items, and drop rates.

## Features

- **Multi-tier Loot System**: Four tiers (Common, Rare, Epic, Legendary) with different prices and drop rates
- **Secure Random Generation**: Custom random number generator for fair item distribution
- **Inventory Management**: Track user items and loot boxes
- **Gift System**: Transfer unopened loot boxes to other users
- **Administrative Controls**: Owner-only functions for contract management
- **Revenue Tracking**: Monitor total sales and contract balance
- **Pause Functionality**: Emergency pause capability

## Contract Structure

### Tiers and Pricing

| Tier | ID | Price (STX) | Description |
|------|----|-----------  |-------------|
| Common | 1 | 1 STX | Basic tier with common items |
| Rare | 2 | 5 STX | Uncommon items with better value |
| Epic | 3 | 15 STX | High-value items with low drop rates |
| Legendary | 4 | 50 STX | Premium tier with exclusive items |

### Default Items

| Item ID | Name | Tier | Value (STX) | Max Supply |
|---------|------|------|-------------|------------|
| 1 | Common Sword | Common | 0.5 | 1000 |
| 2 | Rare Shield | Rare | 2 | 500 |
| 3 | Epic Armor | Epic | 8 | 100 |
| 4 | Legendary Weapon | Legendary | 40 | 25 |

## Public Functions

### User Functions

#### `purchase-loot-box`
Purchase a loot box of specified tier.
```clarity
(purchase-loot-box (tier uint))
```
- **Parameters**: `tier` - The tier of loot box (1-4)
- **Returns**: Loot box ID
- **Cost**: Varies by tier (1-50 STX)

#### `open-loot-box`
Open a purchased loot box to receive a random item.
```clarity
(open-loot-box (box-id uint))
```
- **Parameters**: `box-id` - ID of the loot box to open
- **Returns**: Item ID received
- **Requirements**: Must own the loot box and it must be unopened

#### `gift-loot-box`
Transfer an unopened loot box to another user.
```clarity
(gift-loot-box (box-id uint) (recipient principal))
```
- **Parameters**: 
  - `box-id` - ID of the loot box to gift
  - `recipient` - Principal address of the recipient
- **Returns**: Boolean success
- **Requirements**: Must own the loot box and it must be unopened

### Administrative Functions

#### `update-loot-box-price`
Update the price of a loot box tier (admin only).
```clarity
(update-loot-box-price (tier uint) (new-price uint))
```

#### `add-loot-item`
Add a new item to the loot pool (admin only).
```clarity
(add-loot-item (item-id uint) (name (string-ascii 64)) (tier uint) (rarity uint) (value uint) (max-supply uint))
```

#### `update-drop-rate`
Modify drop rates for specific tier combinations (admin only).
```clarity
(update-drop-rate (tier uint) (item-tier uint) (rate uint))
```

#### `toggle-contract-pause`
Pause or unpause the contract (admin only).
```clarity
(toggle-contract-pause)
```

#### `withdraw-funds`
Withdraw STX from the contract (admin only).
```clarity
(withdraw-funds (amount uint) (recipient principal))
```

#### `transfer-ownership`
Transfer contract ownership (admin only).
```clarity
(transfer-ownership (new-owner principal))
```

## Read-Only Functions

### Data Retrieval

- `get-loot-box (box-id uint)`: Get loot box details
- `get-loot-item (item-id uint)`: Get item information
- `get-user-loot-boxes (user principal)`: Get user's loot boxes
- `get-user-item-balance (user principal) (item-id uint)`: Get user's item quantity
- `get-loot-box-price (tier uint)`: Get tier pricing
- `get-contract-stats`: Get overall contract statistics
- `get-drop-rate (tier uint) (item-tier uint)`: Get drop rate percentages
- `is-box-owner (box-id uint) (user principal)`: Check loot box ownership
- `get-item-supply (item-id uint)`: Get current item supply

## Drop Rate System

Drop rates are configured per tier and determine the probability of receiving items of different rarities. Rates are specified out of 10,000 (100.00%).

### Default Drop Rates

**Common Tier Loot Boxes:**
- Common items: 95% chance
- Rare items: 4.5% chance  
- Epic items: 0.45% chance
- Legendary items: 0.05% chance

**Rare Tier Loot Boxes:**
- Common items: 60% chance
- Rare items: 32% chance
- Epic items: 7% chance
- Legendary items: 1% chance

**Epic Tier Loot Boxes:**
- Common items: 30% chance
- Rare items: 40% chance
- Epic items: 25% chance
- Legendary items: 5% chance

**Legendary Tier Loot Boxes:**
- Common items: 10% chance
- Rare items: 30% chance
- Epic items: 40% chance
- Legendary items: 20% chance

## Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| 100 | ERR-NOT-AUTHORIZED | User not authorized for this action |
| 101 | ERR-INSUFFICIENT-FUNDS | Insufficient STX balance |
| 102 | ERR-INVALID-LOOT-TYPE | Invalid loot type specified |
| 103 | ERR-LOOT-BOX-NOT-FOUND | Loot box does not exist |
| 104 | ERR-ALREADY-OPENED | Loot box already opened |
| 105 | ERR-INVALID-PRICE | Invalid price value |
| 106 | ERR-INVALID-TIER | Invalid tier specified |
| 107 | ERR-INSUFFICIENT-INVENTORY | Item supply exhausted |
| 108 | ERR-TRANSFER-FAILED | STX transfer failed |
| 109 | ERR-INVALID-RECIPIENT | Invalid recipient address |
| 110 | ERR-CONTRACT-PAUSED | Contract is paused |
| 111 | ERR-INVALID-RARITY | Invalid rarity value |
| 112 | ERR-INVALID-RATE | Invalid drop rate |
| 113 | ERR-ITEM-ALREADY-EXISTS | Item ID already exists |
| 114 | ERR-INVALID-VALUE | Invalid item value |
| 115 | ERR-INVALID-SUPPLY | Invalid supply amount |
| 116 | ERR-INVALID-SEED | Invalid random seed |
| 117 | ERR-INVALID-NAME | Invalid item name |

## Security Features

- **Access Control**: Owner-only administrative functions
- **Input Validation**: Comprehensive parameter validation
- **State Checks**: Contract pause functionality
- **Supply Limits**: Maximum supply constraints for items
- **Transfer Protection**: Safe STX transfer mechanisms

## Usage Examples

### Purchase and Open a Loot Box
```clarity
;; Purchase a rare loot box (costs 5 STX)
(contract-call? .fortune-chest purchase-loot-box u2)

;; Open the loot box (assuming box ID 1 was returned)
(contract-call? .fortune-chest open-loot-box u1)
```

### Check Your Inventory
```clarity
;; Get your loot boxes
(contract-call? .fortune-chest get-user-loot-boxes tx-sender)

;; Check balance of item ID 1
(contract-call? .fortune-chest get-user-item-balance tx-sender u1)
```

### Gift a Loot Box
```clarity
;; Gift loot box ID 1 to another user
(contract-call? .fortune-chest gift-loot-box u1 'SP1234567890ABCDEF)
```

