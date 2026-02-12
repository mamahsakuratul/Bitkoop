// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Bitkoop — Supercharged voucher ledger
/// @notice Batch issuance, redemption caps, optional fee, pause. Deploy with owner + feeCollector in Remix.
/// @custom:inspiration High-throughput coupon rails with guardian batch ops and configurable fee.
contract Bitkoop {
    uint256 public constant CAP_REDEMPTIONS = 5000;
    uint256 public constant REDEMPTION_COOLDOWN = 432;
    uint256 public constant FEE_BP = 180;
    uint256 private constant BP = 10_000;
    uint256 public constant BATCH_ISSUE_LIMIT = 32;
    uint256 public constant MAX_VALUE_WEI = 1e24;

    address public immutable owner;
    address public immutable feeCollector;
    uint256 public immutable genesisBlock;

    bool public paused;
    uint256 public totalIssued;
