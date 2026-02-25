# GuardianVault – Social Recovery Wallet with Multi-Guardian Consensus

---

## Overview
GuardianVault enables vault holders to recover wallet access using a multi-guardian confirmation system with time-locked execution and owner override protections.

The contract provides a structured, transparent, and secure framework for decentralized wallet recovery without relying on centralized custodians.

---

# 📌 Problem Statement

Self-custody wallets provide full control — but also full responsibility.  
If private keys are lost or compromised, recovery is often impossible.

GuardianVault solves this by enabling:

- Multi-guardian recovery consensus  
- Time-locked execution windows  
- Vault-holder override during challenge period  
- Transparent on-chain recovery lifecycle  

---

# 🚀 Core Features

## 1️⃣ Recovery Request Creation

Vault holders can initiate a recovery request by specifying:

- Recovery reason  
- New owner proof reference  
- Guardian memo  
- Timelock duration  
- Confirmation threshold  

Each request is assigned a unique on-chain sequence ID.

---

## 2️⃣ Multi-Guardian Confirmation

Guardians can confirm recovery requests by submitting:

- A confirmation weight  
- On-chain confirmation record  

Rules enforced:

- Must be within timelock window  
- Must meet or exceed confirmation threshold  
- Subsequent confirmations must exceed prior weight  

This creates a competitive confirmation model that prevents passive approval attacks.

---

## 3️⃣ Time-Locked Execution Window

Each recovery request has:

- `initiated-at-block`
- `timelock-expiry`

Recovery cannot finalize before timelock expiry.

This ensures:

- Guardians cannot instantly transfer ownership
- Vault holder has time to challenge malicious attempts

---

## 4️⃣ Vault Holder Override

Vault holders may:

- **Halt recovery** during the timelock window  
- **Cancel recovery** if no confirmations exist  

This prevents malicious guardian coordination.

---

## 5️⃣ Processing Fee Mechanism

GuardianVault includes a configurable processing fee:

- Stored in basis points (default: 100 = 1%)
- Capped at 10% maximum
- Adjustable only by vault admin

Fee computation:

```
fee = (amount * processing-fee-bps) / 10000
```

---

# 🧱 Contract Architecture

## Data Structures

### recovery-requests (map)

Stores:

- vault-holder
- recovery-reason
- new-owner-proof
- guardian-memo
- initiated-at-block
- timelock-expiry
- confirmation-threshold
- guardian-confirmations
- primary-guardian
- open-for-confirmation
- executed

---

### guardian-confirmations (map)

Tracks:

- request-seq
- guardian
- confirmation-weight
- confirmed-at-block

---

### Data Variables

- `request-sequence` – incremental ID
- `processing-fee-bps` – configurable basis points
- `vault-admin` – contract deployer

---

# 🔐 Security Design Principles

## Block-Height Enforcement
Timelocks rely on `block-height` for deterministic execution.

## Strict Role Separation

- Vault Holder → initiates, halts, cancels
- Guardians → confirm recovery
- Vault Admin → adjusts processing fee

## Competitive Confirmation Model
Each new confirmation must exceed previous confirmation weight.

Prevents:
- Low-weight spam confirmations
- Passive guardian collusion

## Owner Challenge Protection
Vault holder retains override authority during timelock window.

---

# 📜 Public Functions

## Recovery Lifecycle

- `initiate-recovery`
- `confirm-recovery`
- `halt-recovery`
- `cancel-recovery`

## Administrative

- `update-processing-fee`

## Read-Only

- `get-recovery-request`
- `get-guardian-confirmation`
- `request-on-file`
- `is-open-for-confirmation`
- `is-recovery-executed`
- `get-next-request-seq`
- `get-processing-fee-bps`
- `compute-processing-fee`

---

# 🛡 Error Codes

Error range: `u900 – u915`

Examples:

- `err-request-absent`
- `err-insufficient-guardians`
- `err-not-vault-holder`
- `err-guardian-already-confirmed`
- `err-timelock-active`
- `err-threshold-not-reached`

---

# 🧪 Suggested Future Improvements

- Explicit guardian registration system
- Weighted guardian trust scores
- Slashing mechanism for malicious confirmations
- Event logging standardization
- Multi-vault support per principal
- Automated execution function post timelock

---

# 🎯 Why This Matters

GuardianVault moves social recovery fully on-chain.

It replaces:

- Centralized recovery custodians
- Email-based identity checks
- Off-chain arbitration

With:

- Transparent consensus
- Deterministic timelocks
- On-chain guardian coordination

This contract provides a foundation for secure, decentralized identity recovery infrastructure on Stacks.
