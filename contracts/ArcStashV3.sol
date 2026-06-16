// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ArcStashV3 {
    IERC20 public token;
    address public owner;
    uint256 public constant MAX_VAULTS = 5;
    uint256 public totalPenalties;
    uint256 public totalLocked;
    uint256 public totalVaultsCreated;

    struct Vault {
        uint256 amount;
        uint256 unlockTime;
        uint256 createdAt;
        address depositor;
        address recipient;
        string label;
        bool active;
        bool earlyWithdrawn;
    }

    mapping(address => uint256[]) public userDepositedVaults;
    mapping(address => uint256[]) public userReceivableVaults;
    Vault[] public allVaults;

    event Deposited(uint256 indexed vaultId, address indexed depositor, address indexed recipient, uint256 amount, uint256 unlockTime, string label);
    event Withdrawn(uint256 indexed vaultId, address indexed recipient, uint256 amount);
    event EarlyWithdrawn(uint256 indexed vaultId, address indexed withdrawer, uint256 amountReceived, uint256 penaltyAmount);
    event PenaltiesCollected(address indexed owner, uint256 amount);

    constructor(address _tokenAddress) {
        token = IERC20(_tokenAddress);
        owner = msg.sender;
    }

    function deposit(uint256 _amount, uint256 _lockDays, string calldata _label) external {
        _createVault(msg.sender, msg.sender, _amount, _lockDays, _label);
    }

    function depositFor(address _recipient, uint256 _amount, uint256 _lockDays, string calldata _label) external {
        require(_recipient != address(0), "Invalid recipient");
        _createVault(msg.sender, _recipient, _amount, _lockDays, _label);
    }

    function bulkDepositFor(address[] calldata _recipients, uint256[] calldata _amounts, uint256[] calldata _lockDays, string[] calldata _labels) external {
        require(_recipients.length == _amounts.length, "Arrays length mismatch");
        require(_recipients.length == _lockDays.length, "Arrays length mismatch");
        require(_recipients.length == _labels.length, "Arrays length mismatch");
        require(_recipients.length <= 10, "Max 10 per batch");
        for (uint256 i = 0; i < _recipients.length; i++) {
            require(_recipients[i] != address(0), "Invalid recipient");
            _createVault(msg.sender, _recipients[i], _amounts[i], _lockDays[i], _labels[i]);
        }
    }

    function _createVault(address _depositor, address _recipient, uint256 _amount, uint256 _lockDays, string calldata _label) internal {
        require(_amount > 0, "Amount must be greater than 0");
        require(_lockDays > 0, "Lock period must be at least 1 day");
        require(getActiveVaultCount(_recipient) < MAX_VAULTS, "Recipient has max 5 active vaults");
        token.transferFrom(_depositor, address(this), _amount);
        uint256 vaultId = allVaults.length;
        allVaults.push(Vault({ amount: _amount, unlockTime: block.timestamp + (_lockDays * 1 days), createdAt: block.timestamp, depositor: _depositor, recipient: _recipient, label: _label, active: true, earlyWithdrawn: false }));
        userDepositedVaults[_depositor].push(vaultId);
        if (_depositor != _recipient) { userReceivableVaults[_recipient].push(vaultId); }
        totalLocked += _amount;
        totalVaultsCreated++;
        emit Deposited(vaultId, _depositor, _recipient, _amount, block.timestamp + (_lockDays * 1 days), _label);
    }

    function withdraw(uint256 _vaultId) external {
        require(_vaultId < allVaults.length, "Vault does not exist");
        Vault storage vault = allVaults[_vaultId];
        require(vault.active, "Vault already withdrawn");
        require(msg.sender == vault.recipient, "Only recipient can withdraw");
        require(block.timestamp >= vault.unlockTime, "Vault is still locked");
        uint256 amount = vault.amount;
        vault.active = false;
        totalLocked -= amount;
        token.transfer(msg.sender, amount);
        emit Withdrawn(_vaultId, msg.sender, amount);
    }

    function earlyWithdraw(uint256 _vaultId) external {
        require(_vaultId < allVaults.length, "Vault does not exist");
        Vault storage vault = allVaults[_vaultId];
        require(vault.active, "Vault already withdrawn");
        require(msg.sender == vault.recipient, "Only recipient can withdraw");
        require(block.timestamp < vault.unlockTime, "Vault already unlocked, use withdraw");
        uint256 totalDuration = vault.unlockTime - vault.createdAt;
        uint256 elapsed = block.timestamp - vault.createdAt;
        uint256 percentElapsed = (elapsed * 100) / totalDuration;
        uint256 penaltyBps;
        if (percentElapsed < 50) { penaltyBps = 200; }
        else if (percentElapsed < 90) { penaltyBps = 50; }
        else { penaltyBps = 10; }
        uint256 penalty = (vault.amount * penaltyBps) / 10000;
        uint256 amountAfterPenalty = vault.amount - penalty;
        vault.active = false;
        vault.earlyWithdrawn = true;
        totalLocked -= vault.amount;
        totalPenalties += penalty;
        token.transfer(msg.sender, amountAfterPenalty);
        emit EarlyWithdrawn(_vaultId, msg.sender, amountAfterPenalty, penalty);
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
        uint256[] storage deposited = userDepositedVaults[_user];
        for (uint256 i = 0; i < deposited.length; i++) {
            if (allVaults[deposited[i]].active && allVaults[deposited[i]].recipient == _user) { count++; }
        }
        uint256[] storage receivable = userReceivableVaults[_user];
        for (uint256 i = 0; i < receivable.length; i++) {
            if (allVaults[receivable[i]].active) { count++; }
        }
    }

    function getVault(uint256 _vaultId) external view returns (uint256 amount, uint256 unlockTime, uint256 createdAt, address depositor, address recipient, string memory label, bool active, bool earlyWithdrawn, uint256 timeLeft) {
        require(_vaultId < allVaults.length, "Vault does not exist");
        Vault storage vault = allVaults[_vaultId];
        amount = vault.amount; unlockTime = vault.unlockTime; createdAt = vault.createdAt; depositor = vault.depositor; recipient = vault.recipient; label = vault.label; active = vault.active; earlyWithdrawn = vault.earlyWithdrawn;
        timeLeft = (block.timestamp < vault.unlockTime && vault.active) ? vault.unlockTime - block.timestamp : 0;
    }

    function getUserDepositedVaults(address _user) external view returns (uint256[] memory) { return userDepositedVaults[_user]; }
    function getUserReceivableVaults(address _user) external view returns (uint256[] memory) { return userReceivableVaults[_user]; }
    function getTotalVaults() external view returns (uint256) { return allVaults.length; }
}
