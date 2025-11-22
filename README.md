# Behavior-Triggered 2FA Wallet Smart Contract

A Clarity smart contract implementing a behavior-based two-factor authentication (2FA) wallet on Stacks blockchain.

## Overview

This smart contract provides enhanced security for STX transfers by requiring guardian approval when:
- Transfer amount exceeds a configurable threshold
- Recipient is a new/unknown address

## Features

✅ **Owner-Controlled Transfers** - Only contract owner can initiate transfers  
✅ **Guardian 2FA Approval** - Guardian must approve high-risk transfers  
✅ **Dynamic Threshold** - Owner can set custom approval thresholds  
✅ **Recipient Tracking** - Maintains list of known recipients  
✅ **Pending Transfer Management** - Cancel or approve pending transfers  
✅ **Transfer Flexibility** - Normal transfers bypass 2FA if conditions are met  

## Key Functions

### Owner Functions
- `transfer(amount, recipient)` - Initiate a transfer (may require 2FA)
- `set-threshold(new-threshold)` - Update approval threshold
- `set-guardian(new-g)` - Assign guardian for 2FA approvals
- `cancel-pending()` - Cancel a pending transfer

### Guardian Functions
- `approve-transfer()` - Approve a pending 2FA transfer

### View Functions
- `pending-state()` - Check pending transfer details
- `is-known(recipient)` - Check if recipient is registered

## Security Features

🔒 Principal validation in guardian assignment  
🔒 Transfer amount validation  
🔒 Active pending check to prevent transaction conflicts  
🔒 Owner-only administrative functions  
🔒 Guardian-only approval rights  

## Usage Example

```clarity
;; Owner initiates transfer to new recipient (requires 2FA)
(contract-call? .behavior_2fa_wallet transfer u5000000 'SPXXX...)

;; Guardian approves transfer
(contract-call? .behavior_2fa_wallet approve-transfer)
