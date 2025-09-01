### 1. Overview
- Goal: Validate the standalone Blockchain Score Anchoring Module before integration into the website.
- Contract under test: “PongScores” (final name TBD).
- Chain(s): local dev network (Hardhat) and Avalanche Fuji testnet (43113).
- Tooling assumptions: Hardhat for build/test, ethers.js for interactions.
- Status of MAX_SCORE: TBD. Tests will reference MAX_SCORE placeholder.

###  2. In Scope vs Out of Scope
- In scope: write flow (reportMatch), access control, duplicate prevention, event emission, read helpers (isRecorded), basic gas sanity, non-payable behavior.
- Out of scope: player-signed submissions (EIP-712), complex leaderboards, off-chain storage, UI.

### 3. Environments
- Local: Hardhat in-memory chain for unit tests.
- Testnet: Avalanche Fuji C-Chain (RPC URL TBD, Explorer: testnet.snowtrace.io).
- Accounts:
  - OWNER_ADDRESS: TBD
  - SCOREKEEPER_ADDRESS: TBD (authorized to write)
  - RANDOM_USER_ADDRESS: TBD (unauthorized)

### 4. Test Data and Deterministic Fixtures
- Tournament seed and ID:
  - TOURNAMENT_SEED: e.g., “pong:<normalizedName>:<YYYYMMDD>:<salt>”
  - TOURNAMENT_ID: Keccak-256(TOURNAMENT_SEED) → bytes32
- Player alias normalization: trim, lowercase, collapse spaces.
- Player hashes:
  - PLAYER_A_HASH = Keccak-256(“player:<aliasA_norm>:<TOURNAMENT_ID_hex>”)
  - PLAYER_B_HASH = Keccak-256(“player:<aliasB_norm>:<TOURNAMENT_ID_hex>”)
- Match identifiers: matchId ∈ uint64 (examples: 1, 2, 3).
- Scores: 0..MAX_SCORE (MAX_SCORE = TBD; fill once decided).

### 5. Test Cases Catalogue (AAA: Arrange → Act → Assert)
Nominal writes
- T01 Record one valid match
  - Arrange: deployed contract; scorekeeper set.
  - Act: reportMatch(TOURNAMENT_ID, 1, PLAYER_A_HASH, PLAYER_B_HASH, scoreA, scoreB).
  - Assert: success; ScoreRecorded event emitted with exact fields; isRecorded(TOURNAMENT_ID, 1) == true.

- T02 Record multiple matches
  - Act: record matchId = 1, 2, 3 with valid inputs.
  - Assert: three distinct events; all isRecorded == true.

Access control
- T03 Unauthorized writer
  - Act: reportMatch from RANDOM_USER_ADDRESS.
  - Assert: transaction reverts with NotAuthorized (or equivalent).

- T04 Rotate scorekeeper
  - Act: owner calls setScorekeeper(NEW_ADDR).
  - Assert: old scorekeeper fails; new scorekeeper succeeds; ScorekeeperChanged emitted.

Duplicates and validation
- T05 Duplicate (tournamentId, matchId)
  - Act: call reportMatch twice with same (TOURNAMENT_ID, 1).
  - Assert: second call reverts with DuplicateMatch.

- T06 Invalid inputs
  - 06a tournamentId == 0x00…00 → revert InvalidInput.
  - 06b playerAHash == 0x00…00 or playerBHash == 0x00…00 → revert InvalidInput.
  - 06c playerAHash == playerBHash → revert InvalidInput.
  - 06d scoreA > MAX_SCORE or scoreB > MAX_SCORE → revert InvalidInput.
  - 06e negative scores are impossible by type; ensure no path allows them.

Non-payable and state invariants
- T07 Non-payable behavior
  - Act: attempt to send non-zero value with reportMatch.
  - Assert: revert; contract balance remains zero.

- T08 isRecorded read path
  - Act: query isRecorded on unseen pair, then after write.
  - Assert: false before; true after.

Events and indexing
- T09 Event topics and payload
  - Act: filter events by tournamentId (indexed) and matchId (indexed).
  - Assert: only events for that tournament are returned; payload matches inputs (player hashes, scores, reporter not zero, timestamp > 0).

Bounds and gas sanity
- T10 Bounds
  - Act: use large matchId close to uint64 max; use scores at edges (0 and MAX_SCORE).
  - Assert: success for in-range values.

- T11 Gas baseline (informational)
  - Act: estimate/report gas for reportMatch with typical inputs.
  - Assert: within an acceptable range (threshold TBD; document observed value).

No funds and no external calls
- T12 Zero balance invariant
  - Assert: contract balance is always zero after all tests.

Hashing coherence (off-chain vs on-chain usage)
- T13 Off-chain hash determinism
  - Act: compute player hashes off-chain once; reuse across tests.
  - Assert: hashes observed in events equal the precomputed values.

### 6. Test Organization and Quality Rules
- Each test isolates state (fresh fixture or snapshot).
- Assert both revert reason (error selector) and that no state changed on failure.
- Verify all event fields explicitly (ids, hashes, scores, reporter, timestamp).
- No hidden ordering dependencies between tests.

### 7. Fuji Testnet Integration (manual or scripted)
- I01 Deploy on Fuji; record at least three matches across one tournament.
- I02 Verify events on Snowtrace (paste links in this document).
- I03 Read back matches via the future SDK or a simple read script and compare to inputs.
- I04 Confirm contract holds zero funds and has correct owner/scorekeeper addresses.

### 8. Acceptance Criteria (Definition of Done for testing)
- All unit tests T01–T09 pass locally.
- At least T10–T13 validated once and documented.
- Three ScoreRecorded events visible on Fuji with the expected fields.
- No PII visible on-chain (manual review of event logs).
- Gas baseline noted for a typical reportMatch call.

### 9. Reporting
- Record:
  - Contract name, version, address, deployment block.
  - Owner and scorekeeper addresses.
  - Links to Fuji transactions and logs.
- Document MAX_SCORE final value and where it is enforced.
- Known limitations and future work (e.g., V2 with player signatures).

### 10. Known Limitations
- Trust in scorekeeper for V1 (can write incorrect scores if compromised).
- Event-only history; leaderboards computed off-chain.
- No anti-spam beyond access control.

### 11. Traceability
- Map each SPEC.md requirement to one or more tests:
  - Access control → T03, T04
  - Duplicate prevention → T05
  - Input validation → T06
  - Non-payable → T07
  - Event emission/indexing → T01, T02, T09
  - Minimal state / zero balance → T07, T12
