# ft_transcendence -- Blockchain Score Anchoring Module (Standalone)

### 1) Purpose and Scope
- Goal: Anchor Pong tournament match results on a public, tamper-evident ledger (Avalanche Fuji testnet) and make them retrievable by the website later.
- Principle: Minimize on-chain state and rely on Events (logs) for history. Avoid storing personally identifiable information (PII).

### 2) High-Level Design
- One smart contract exposes a single write method to record a match result and emits an event ScoreRecorded.
- A single “scorekeeper” address is authorized to write (MVP). Reading is done off-chain by filtering events.
- A small TypeScript SDK (separate package) provides a stable interface for both backend or frontend integration later.

### 3) Data Model (on-chain)
- tournamentId: bytes32 (Keccak-256 of a tournament seed: normalized name + date + salt), stable and non-PII.
- matchId: uint64, unique per tournamentId.
- playerAHash, playerBHash: bytes32, pseudonymous player identifiers (Keccak-256 of normalized alias + tournamentId).
- scoreA, scoreB: uint16 (0–65535); practical upper bound may be enforced in validation.
- reporter: address (implicit: msg.sender), included in the event.
- timestamp: block timestamp (emitted in the event, not stored).

On-chain storage kept minimal:
- owner: address (contract owner).
- scorekeeper: address (authorized writer).
- recorded[tournamentId][matchId]: bool to prevent duplicates.

### 4) Public Interface (conceptual, not code)
- reportMatch(tournamentId, matchId, playerAHash, playerBHash, scoreA, scoreB)
  - Effects: validates inputs and permissions; ensures (tournamentId, matchId) not seen; marks it recorded; emits ScoreRecorded.
  - Access: only scorekeeper can call.
  - Payable: no (value must be zero).
- setScorekeeper(newScorekeeper)
  - Access: only owner (deployer).
  - Emits: ScorekeeperChanged(old, new).
- getScorekeeper() → address (view)
- isRecorded(tournamentId, matchId) → bool (view, optional for client UX)

Events (with up to 3 indexed params for efficient filtering):
- ScoreRecorded(tournamentId indexed, matchId indexed, playerAHash, playerBHash, scoreA, scoreB, reporter, timestamp)
- ScorekeeperChanged(oldScorekeeper, newScorekeeper)

Indexing policy:
- Index tournamentId and matchId to filter fast per tournament and match.
- Keep playerAHash non-indexed to reduce gas (can be filtered client-side if needed).

### 5) Access Control and Roles
- owner: address that deployed the contract; can rotate the scorekeeper.
- scorekeeper: only account allowed to call reportMatch.
- Rationale: simple governance, easy to demo; can evolve to player-signed submissions in a v2.

### 6) Input Validation and Error Catalog
- Authorization: revert if msg.sender != scorekeeper (error NotAuthorized).
- Duplicates: revert if recorded[tournamentId][matchId] is true (error DuplicateMatch).
- Null checks: revert if tournamentId == 0x0, playerAHash == 0x0, playerBHash == 0x0 (error InvalidInput).
- Score bounds: enforce scoreA <= 255 and scoreB <= 255 (or another explicit max) to encode classic Pong; else InvalidInput.
- Self-consistency: allow playerAHash == playerBHash? No; reject same players in one match (InvalidInput).

### 7) Privacy and Compliance
- No PII on-chain. Never store aliases, emails, or user IDs in clear.
- Pseudonymization: playerHash = Keccak-256(normalizedAlias + tournamentId). Normalization rules must be documented and deterministic.
- The mapping alias ↔ hash is kept off-chain (in your backend DB or ephemeral memory for tournaments without accounts).

### 8) Gas, Security, and Simplicity Constraints
- No loops over unbounded arrays; constant-time operations only.
- No external calls; no reentrancy surface.
- All functions are non-payable; contract holds no funds.
- Event-centric design to keep state small and writes cheap.

### 9) Environments and Configuration
- Target chain: Avalanche Fuji C-Chain (Chain ID 43113).
- Recommended RPC: https://chainlist.org/chain/43113
- Explorer: https://testnet.snowtrace.io
- Secrets:
  - TESTNET_PRIVATE_KEY (scorekeeper) stored in .env (never committed).
  - RPC_URL, CHAIN_ID, CONTRACT_ADDRESS in env per environment (local, testnet).
- Tooling: Hardhat for build/test/deploy; ethers.js for interactions.

### 10) SDK Contract (TypeScript package interface)
- init(config)
  - Inputs: rpcUrl, chainId, contractAddress, optional signerPrivateKey (for server-side writes).
  - Behavior: builds provider + optional signer; loads contract by ABI+address.
- reportMatch(input)
  - Inputs: tournamentId (0x…32 bytes), matchId (number/bigint), playerAHash (0x…32 bytes), playerBHash (0x…32 bytes), scoreA (number), scoreB (number).
  - Behavior: sends a transaction from the signer; returns txHash and waits for receipt when requested.
  - Errors: InvalidArgs, NotAuthorized (revert), RpcError, TxReverted, WrongChain.
- getTournamentMatches(tournamentId, options)
  - Behavior: scans ScoreRecorded events filtered by tournamentId; returns a normalized array sorted by matchId or block time.
  - Options: fromBlock/toBlock, pagination, dedup policy.
- watchTournament(tournamentId, handler)
  - Behavior: subscribes to new ScoreRecorded events for live updates.

### 11) Demo Application (standalone, choose one)
- CLI:
  - add-match: takes tournamentId, matchId, aliases (or pre-hashed), scores; performs hashing if needed; calls reportMatch; prints explorer link.
  - list-matches: takes tournamentId; prints history from events.
- Micro-API:
  - POST /tournaments/:id/matches → body with matchId, aliases or playerHashes, scores; responds with tx hash and status.
  - GET /tournaments/:id/matches → returns reconstructed history.

Both variants must validate inputs and hide secrets; use HTTPS/WSS in real deployments.

### 12) Testing Strategy (Hardhat)
- Unit tests (local network):
  - Nominal: one match recorded; event emitted; isRecorded true afterwards.
  - Duplicate: second write same (tournamentId, matchId) reverts.
  - Auth: non-scorekeeper write reverts.
  - Rotation: owner changes scorekeeper; old fails, new succeeds.
  - Bounds: invalid ids, zero hashes, out-of-range scores revert.
- Integration tests (Fuji):
  - Deploy; record 2–3 matches; verify events on Snowtrace; read back via SDK and compare.

### 13) Deployment and Versioning
- Contract name and version string embedded in a public constant (for discovery).
- Store deployment metadata per environment: address, ABI, chainId, blockNumber of deployment, owner, scorekeeper.
- Roll-forward strategy: if spec evolves, deploy v2 and update SDK config. Old data remains queryable via events.

### 14) Observability and Ops
- Logs: the demo prints tx hashes and explorer URLs.
- Rate limits: handle RPC provider rate limits with retries and backoff.
- Docker: provide a one-command run that starts the demo (CLI help or API server) and reads env vars for RPC/keys.

### 15) Risks and Future Work
- Compromised scorekeeper can write bad results. Mitigation in v2: require EIP-712 signatures from both players and verify on-chain.
- Event-only history means any “leaderboard” is computed off-chain. This is intended and cheaper.
- Consider chain reorg handling in the SDK’s “watch” feature (confirmations > 1).

### 16) Definition of Done (acceptance)
- Contract deployed on Avalanche Fuji; address and ABI documented.
- At least three ScoreRecorded events visible on Snowtrace for a sample tournament.
- SDK can write a match (with signer) and read all matches via events.
- Demo (CLI or API) works end-to-end; Dockerized; README explains setup, env, and testing steps.
- No PII on-chain; keys and secrets never committed; HTTPS/WSS ready for integration.

### 17) Appendix — ID and Hashing Scheme (off-chain)
- Normalize alias: trim, lowercase (Unicode-aware), collapse spaces.
- tournamentId: Keccak-256 of a canonical seed such as “pong:\<normalizedName\>:\<YYYYMMDD\>:\<randomSalt\>”.
- playerHash: Keccak-256 of “player:\<normalizedAlias\>:\<tournamentIdHex\>”.
- Store the mapping alias ↔ playerHash off-chain for the duration of the tournament.
