// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract PongScores {
	// Errors (gas‑efficient)
	error NotAuthorized(); 
	error DuplicateMatch();
	error InvalidInput();
	error ZeroAddress();

	// Constants
	uint16 public constant MAX_SCORE = 21;

	// Roles
	address public owner;
	address private _scorekeeper;

	// Storage: (tournamentId, matchId) -> recorded?
	mapping(bytes32 => mapping(uint64 => bool)) private recorded;

	// Events
	event ScoreRecorded(
		bytes32 indexed tournamentId,
		uint64 indexed matchId,
		bytes32 playerAHash,
		bytes32 playerBHash,
		uint16 scoreA,
		uint16 scoreB,
		address reporter,
		uint256 timestamp
	);

	event ScorekeeperChanged(address indexed oldScorekeeper, address indexed newScorekeeper);

	constructor(address initialScorekeeper) {
		owner = msg.sender;
		if (initialScorekeeper == address(0)) revert ZeroAddress();
		_scorekeeper = initialScorekeeper;
		emit ScorekeeperChanged(address(0), initialScorekeeper);
	}

	modifier onlyOwner() {
		if (msg.sender != owner) revert NotAuthorized();
		_;
	}

	function getScorekeeper() external view returns (address) {
		return _scorekeeper;
	}

	function isRecorded(bytes32 tournamentId, uint64 matchId) external view returns (bool) {
		return recorded[tournamentId][matchId];
	}

	function setScorekeeper(address newScorekeeper) external onlyOwner {
		if (newScorekeeper == address(0)) revert ZeroAddress();
		address old = _scorekeeper;
		_scorekeeper = newScorekeeper;
		emit ScorekeeperChanged(old, newScorekeeper);
	}

	function reportMatch(
		bytes32 tournamentId,
		uint64 matchId,
		bytes32 playerAHash,
		bytes32 playerBHash,
		uint16 scoreA,
		uint16 scoreB
	) external {
		if (msg.sender != _scorekeeper) revert NotAuthorized();
		if (tournamentId == bytes32(0)) revert InvalidInput();
		if (playerAHash == bytes32(0) || playerBHash == bytes32(0)) revert InvalidInput();
		if (playerAHash == playerBHash) revert InvalidInput();
		if (scoreA > MAX_SCORE || scoreB > MAX_SCORE) revert InvalidInput();
		if (recorded[tournamentId][matchId]) revert DuplicateMatch();

		recorded[tournamentId][matchId] = true;

		emit ScoreRecorded(
			tournamentId,
			matchId,
			playerAHash,
			playerBHash,
			scoreA,
			scoreB,
			msg.sender,
			block.timestamp
		);
	}
}
