# ArcStash

Non-custodial, time-locked stablecoin vaults and payroll on [Arc Testnet](https://testnet.arcscan.app). Lock USDC or EURC for a chosen period, pay contractors on a schedule, send instantly, or bridge to Ethereum/Base via Circle CCTP V2 — all from a single-page dApp.

## Features

- **USDC & EURC Vaults** — Lock stablecoins with a custom time period and optional label
- **Smart Penalty** — Early withdrawal penalty scales with time: 2% (early) → 0.5% (mid) → 0.1% (near unlock)
- **Onchain Payroll** — Lock funds for contractors with `depositFor`, they claim on payday
- **Bulk Payroll** — Pay up to 10 people in one transaction with `bulkDepositFor`
- **Instant Send** — Direct stablecoin transfers with no lock
- **Cross-Chain Bridge** — Send USDC from Arc to Ethereum/Base via Circle CCTP V2

## Deployed Contracts (Arc Testnet)

### Active (V3 — used by live frontend)
| Contract | Token | Address |
|----------|-------|---------|
| ArcStash USDC | USDC | `0xB66a7FBbe950E9D37D396CEB4998b9f2E83aC25F` |
| ArcStash EURC | EURC | `0x8d5921fFb9b0B925daA6D009A0581D20697c5444` |

### Previous Versions (deprecated)
| Contract | Token | Address |
|----------|-------|---------|
| V2 USDC | USDC | `0x487C0a96D51e6064c15B81466f78Cc1Fe9396af5` |
| V2 EURC | EURC | `0x1A3f16C32cD001d34803532fc4CE1513A3531061` |

### Token Addresses
| Token | Address |
|-------|---------|
| USDC | `0x3600000000000000000000000000000000000000` |
| EURC | `0x89B50855Aa3bE2F677cD6303Cec089B5F319D72a` |

## Repository Structure

```
.
├── index.html                  # The entire dApp (HTML/CSS/JS, single file)
├── contracts/
│   ├── ArcStashV3.sol          # Active vault contract (time-scaled penalty)
│   └── USDCVaultV2.sol         # Deprecated V2 (flat 10% penalty)
└── arclogo.png.png             # App logo
```

## Contracts

The active **ArcStashV3** contract powers the live frontend. Each recipient may hold up to 5 active vaults. Early withdrawals apply a time-scaled penalty (200 → 50 → 10 bps) that accrues to the contract owner; standard withdrawals after the unlock time return the full amount.

The deprecated **USDCVaultV2** is the earlier "basic" vault with a flat 10% early-withdrawal penalty, kept for reference.

Both compile with Solidity `^0.8.28` and depend on OpenZeppelin's `IERC20`.

## Local Development

The frontend is a single static file — no build step:

```bash
npx serve -l 3000 -s .
```

Then open <http://localhost:3000>.
