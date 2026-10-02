# Raffle

[![CI](https://github.com/agent-mino/Raffle/actions/workflows/test.yml/badge.svg)](https://github.com/agent-mino/Raffle/actions/workflows/test.yml)

A provably fair, trustless lottery on Ethereum. Players enter by paying an entrance fee; after a configurable time interval a winner is selected using **Chainlink VRF v2.5** and the full pot is transferred to them. **Chainlink Automation** triggers the draw automatically — no keeper wallet, no cron job, no trusted operator.

## How it works

```
enterRaffle() [payable, ≥ entranceFee]
  └─▶ player added to s_participants
        └─▶ RaffleEntered event

checkUpkeep() [polled by Chainlink Automation]
  checks: time elapsed AND raffle OPEN AND contract has ETH AND has participants
        └─▶ returns upkeepNeeded = true when all four hold

performUpkeep()
  └─▶ state → CALCULATING (blocks new entries during VRF request)
        └─▶ requests random word from Chainlink VRF coordinator
              └─▶ RequestedRaffleWinner event

fulfillRandomWords() [VRF coordinator callback]
  └─▶ winner = participants[randomWord % participants.length]
        └─▶ state → OPEN, participants reset, timestamp reset
              └─▶ transfers entire balance to winner
                    └─▶ WinnerPicked event
```

## Design decisions

- **Chainlink VRF v2.5** — the random word is generated off-chain with a cryptographic proof verified on-chain, so neither the contract owner nor the Chainlink node can predict or influence the outcome.
- **State machine** — `RaffleState.CALCULATING` blocks new entries while a VRF request is in flight, preventing a participant from timing an entry around the draw.
- **3 block confirmations** — the VRF request waits for 3 confirmation blocks before callback, reducing the window for chain-reorg manipulation.
- **Immutable config** — entrance fee, interval, VRF coordinator, gas lane, and subscription ID are set at deploy time and cannot be changed.

## Tech stack

Solidity 0.8.19 · Chainlink VRF v2.5 · Chainlink Automation · Foundry (Forge + Anvil)

## Run locally

Requires [Foundry](https://book.getfoundry.sh/getting-started/installation).

```bash
git clone --recurse-submodules https://github.com/agent-mino/Raffle.git
cd Raffle
forge build
forge test
```

## Deploy

The deploy script auto-creates and funds a Chainlink VRF subscription when running against local Anvil; on Sepolia it expects an existing subscription ID set in `HelperConfig`.

```bash
# Local Anvil node
anvil &
forge script script/DeployRaffle.s.sol --broadcast --rpc-url http://127.0.0.1:8545 --private-key <ANVIL_KEY>

# Sepolia testnet (set PRIVATE_KEY and SEPOLIA_RPC_URL in .env)
forge script script/DeployRaffle.s.sol --broadcast --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
```

## CI

Every push runs `forge fmt --check`, `forge build --sizes`, and `forge test -vvv`.
