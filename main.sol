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

    function issueVoucher(bytes32 voucherId, address issuer, uint256 valueWei) external onlyOwner whenNotPaused {
        if (issuer == address(0)) revert Bitkoop_ZeroAddress();
        if (valueWei == 0) revert Bitkoop_ZeroAmount();
        if (voucherId == bytes32(0)) revert Bitkoop_BadVoucherId();
        if (valueWei > MAX_VALUE_WEI) revert Bitkoop_ValueTooHigh();
        totalIssued += 1;
        emit Issued(voucherId, issuer, valueWei, block.number);
    }

    function issueVouchersBatch(
        bytes32[] calldata voucherIds,
        address[] calldata issuers,
        uint256[] calldata valuesWei
    ) external onlyOwner whenNotPaused {
        uint256 n = voucherIds.length;
        if (n == 0 || n > BATCH_ISSUE_LIMIT) revert Bitkoop_BatchTooBig();
        if (issuers.length != n || valuesWei.length != n) revert Bitkoop_Forbidden();
        for (uint256 i = 0; i < n; i++) {
            if (issuers[i] == address(0)) revert Bitkoop_ZeroAddress();
            if (valuesWei[i] == 0) revert Bitkoop_ZeroAmount();
            if (voucherIds[i] == bytes32(0)) revert Bitkoop_BadVoucherId();
            if (valuesWei[i] > MAX_VALUE_WEI) revert Bitkoop_ValueTooHigh();
            totalIssued += 1;
            emit Issued(voucherIds[i], issuers[i], valuesWei[i], block.number);
        }
        emit IssuedBatch(n, block.number);
    }

    function redeemVoucher(bytes32 voucherId, uint256 valueWei) external whenNotPaused {
        if (used[voucherId]) revert Bitkoop_AlreadyUsed();
        if (valueWei == 0) revert Bitkoop_ZeroAmount();
        if (block.number < lastRedeemBlock[msg.sender] + REDEMPTION_COOLDOWN) revert Bitkoop_Cooldown();
        if (_slots.length >= CAP_REDEMPTIONS) revert Bitkoop_CapReached();
        if (valueWei > MAX_VALUE_WEI) revert Bitkoop_ValueTooHigh();

        uint256 feeWei = (valueWei * FEE_BP) / BP;
        totalFeesWei += feeWei;

        used[voucherId] = true;
        lastRedeemBlock[msg.sender] = block.number;
        userRedeemCount[msg.sender] += 1;
        totalRedeemed += 1;

        _slots.push(RedeemSlot({
            blockNum: block.number,
            vid: voucherId,
            valueWei: valueWei,
            user: msg.sender
        }));
        emit Redeemed(_slots.length - 1, voucherId, msg.sender, valueWei, feeWei);
    }

    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
        emit PauseSet(_paused);
    }

    function withdrawFees(address payable to) external onlyOwner {
        if (to == address(0)) revert Bitkoop_ZeroAddress();
        uint256 amount = address(this).balance;
        if (amount == 0) return;
        (bool ok,) = to.call{value: amount}("");
        if (!ok) revert Bitkoop_Forbidden();
        emit FeeWithdrawn(to, amount);
    }

    function logNote(bytes32 topic, uint256 data) external onlyOwner {
        emit OwnerNote(topic, data);
    }

