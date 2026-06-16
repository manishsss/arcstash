// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract USDCVaultV2 {
    IERC20 public token;
    address public owner;
    uint256 public constant MAX_VAULTS = 5;
    uint256 public constant PENALTY_PERCENT = 10;
    uint256 public totalPenalties;
    uint256 public totalLocked;

    struct Vault {
        uint256 amount;
        uint256 unlockTime;
        uint256 createdAt;
        bool active;
    }

    mapping(address => Vault[]) public userVaults;

    event Deposited(address indexed user, uint256 vaultIndex, uint256 amount, uint256 unlockTime);
    event Withdrawn(address indexed user, uint256 vaultIndex, uint256 amount);
    event EarlyWithdrawn(address indexed user, uint256 vaultIndex, uint256 amountReceived, uint256 penaltyAmount);
    event PenaltiesCollected(address indexed owner, uint256 amount);

    constructor(address _tokenAddress) {
        token = IERC20(_tokenAddress);
        owner = msg.sender;
    }

    function deposit(uint256 _amount, uint256 _lockDays) external {
        require(_amount > 0, "Amount must be greater than 0");
        require(_lockDays > 0, "Lock period must be at least 1 day");
        require(getActiveVaultCount(msg.sender) < MAX_VAULTS, "Max 5 active vaults");
        token.transferFrom(msg.sender, address(this), _amount);
        userVaults[msg.sender].push(Vault({
            amount: _amount,
            unlockTime: block.timestamp + (_lockDays * 1 days),
            createdAt: block.timestamp,
            active: true
        }));
        totalLocked += _amount;
        emit Deposited(msg.sender, userVaults[msg.sender].length - 1, _amount, block.timestamp + (_lockDays * 1 days));
    }

    function withdraw(uint256 _vaultIndex) external {
        require(_vaultIndex < userVaults[msg.sender].length, "Vault does not exist");
        Vault storage vault = userVaults[msg.sender][_vaultIndex];
        require(vault.active, "Vault already withdrawn");
        require(block.timestamp >= vault.unlockTime, "Vault is still locked");
        uint256 amount = vault.amount;
        vault.active = false;
        totalLocked -= amount;
        token.transfer(msg.sender, amount);
        emit Withdrawn(msg.sender, _vaultIndex, amount);
    }

    function earlyWithdraw(uint256 _vaultIndex) external {
        require(_vaultIndex < userVaults[msg.sender].length, "Vault does not exist");
        Vault storage vault = userVaults[msg.sender][_vaultIndex];
        require(vault.active, "Vault already withdrawn");
        require(block.timestamp < vault.unlockTime, "Vault already unlocked, use withdraw");
        uint256 penalty = (vault.amount * PENALTY_PERCENT) / 100;
        uint256 amountAfterPenalty = vault.amount - penalty;
        vault.active = false;
        totalLocked -= vault.amount;
        totalPenalties += penalty;
        token.transfer(msg.sender, amountAfterPenalty);
        emit EarlyWithdrawn(msg.sender, _vaultIndex, amountAfterPenalty, penalty);
    }

    function collectPenalties() external {
        require(msg.sender == owner, "Only owner");
        require(totalPenalties > 0, "No penalties to collect");
        uint256 amount = totalPenalties;
        totalPenalties = 0;
        token.transfer(owner, amount);
        emit PenaltiesCollected(owner, amount);
    }

    function getActiveVaultCount(address _user) public view returns (uint256 count) {
        for (uint256 i = 0; i < userVaults[_user].length; i++) {
            if (userVaults[_user][i].active) count++;
        }
    }

    function getUserVaults(address _user) external view returns (Vault[] memory) {
        return userVaults[_user];
    }

    function getVaultInfo(address _user, uint256 _vaultIndex) external view returns (
        uint256 amount, uint256 unlockTime, uint256 createdAt, uint256 timeLeft, bool active
    ) {
        require(_vaultIndex < userVaults[_user].length, "Vault does not exist");
        Vault storage vault = userVaults[_user][_vaultIndex];
        amount = vault.amount;
        unlockTime = vault.unlockTime;
        createdAt = vault.createdAt;
        active = vault.active;
        timeLeft = (block.timestamp < vault.unlockTime && vault.active) ? vault.unlockTime - block.timestamp : 0;
    }
}
