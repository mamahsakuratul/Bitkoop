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
    uint256 public totalRedeemed;
    uint256 public totalFeesWei;

    struct RedeemSlot {
        uint256 blockNum;
        bytes32 vid;
        uint256 valueWei;
        address user;
    }
    RedeemSlot[] private _slots;
    mapping(bytes32 => bool) public used;
    mapping(address => uint256) public lastRedeemBlock;
    mapping(address => uint256) public userRedeemCount;

    error Bitkoop_Forbidden();
    error Bitkoop_ZeroAddress();
    error Bitkoop_ZeroAmount();
    error Bitkoop_BadVoucherId();
    error Bitkoop_AlreadyUsed();
    error Bitkoop_Cooldown();
    error Bitkoop_CapReached();
    error Bitkoop_Paused();
    error Bitkoop_OutOfRange();
    error Bitkoop_ValueTooHigh();
    error Bitkoop_BatchTooBig();

    event Issued(bytes32 indexed vid, address indexed issuer, uint256 valueWei, uint256 blockNum);
    event IssuedBatch(uint256 count, uint256 blockNum);
    event Redeemed(uint256 indexed slotIdx, bytes32 vid, address indexed user, uint256 valueWei, uint256 feeWei);
    event FeeWithdrawn(address indexed to, uint256 amount);
    event PauseSet(bool paused);
    event OwnerNote(bytes32 topic, uint256 data);

    constructor(address _owner, address _feeCollector) {
        if (_owner == address(0)) revert Bitkoop_ZeroAddress();
        owner = _owner;
        feeCollector = _feeCollector == address(0) ? _owner : _feeCollector;
        genesisBlock = block.number;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert Bitkoop_Forbidden();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert Bitkoop_Paused();
        _;
    }

