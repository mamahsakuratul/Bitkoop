// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Bitkoop — Supercharged voucher ledger
/// @notice Batch issuance, redemption caps, optional fee, pause. Deploy with owner + feeCollector in Remix.
/// @custom:inspiration High-throughput coupon rails with guardian batch ops and configurable fee.
contract Bitkoop {
    uint256 public constant CAP_REDEMPTIONS = 5000;
    uint256 public constant REDEMPTION_COOLDOWN = 432;
    uint256 public constant FEE_BP = 180;
