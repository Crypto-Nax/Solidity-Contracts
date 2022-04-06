// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;
import "./ReentrancyGuard.sol";
import "./IBEP20.sol";
import "./ILocker.sol";

contract Lock is ReentrancyGuard, ILocker {

    address public lpTokens;
    address public lockOwner;
    address public mainLocker;
    uint256 public initialLpAmount;
    uint256 public lpAmount;
    uint256 public dateLocked;
    uint256 public unlockTime;
    uint256 public withdrawalTime;
    uint256 public Id;
    bool public withdrawn;

    mapping(address => mapping(address => uint256)) public walletTokenBalance;

    modifier onlyLocker() {
        require(msg.sender == mainLocker); _;
    }

    constructor(address _lpTokens, address _lockOwner, uint256 amount, uint256 _unlockTime, uint256 _id) payable {
        lpTokens = _lpTokens;
        lockOwner = _lockOwner;
        initialLpAmount = amount;
        Id = _id;
        lpAmount = initialLpAmount;
        dateLocked = block.timestamp;
        unlockTime = _unlockTime;
        walletTokenBalance[_lpTokens][_lockOwner] += amount;
    }

    function getId() external override view returns(uint256) {
        return Id;
    }

    function getTotalTokenBalance() public override view returns (uint256){
        return lpAmount;
    }

    function getLpAddress() external override view returns(address){
        return lpTokens;
    }

    function getUnlockTime() external view override returns(uint256) {
        return unlockTime;
    }
    
    function increaseLockAmount(uint256 amount) external override onlyLocker returns(bool increased){
        lpAmount += amount;
        walletTokenBalance[lpTokens][lockOwner] += lpAmount;
        increased = true;
        return increased;
    }

    function transferLockOwnership(address _lockOwner) external override onlyLocker returns(bool transferred){
        uint256 previousBalance = walletTokenBalance[lpTokens][lockOwner];
        walletTokenBalance[lpTokens][lockOwner] = previousBalance - lpAmount;        
        walletTokenBalance[lpTokens][_lockOwner] += lpAmount;
        lockOwner = _lockOwner;
        transferred = true;
        return transferred;
    }

    function extendLock(uint256 newUnlockTime) external override onlyLocker returns(bool extended) {
        require(!withdrawn, 'Tokens already withdrawn');
        unlockTime = newUnlockTime;
        extended = true;
        return extended;
    }

    function withdrawTokens() external override onlyLocker returns(bool){
        require(IBEP20(lpTokens).transfer(lockOwner, lpAmount), 'Failed to transfer tokens');
        uint256 previousBalance = walletTokenBalance[lpTokens][lockOwner];
        walletTokenBalance[lpTokens][lockOwner] = previousBalance - lpAmount;
        withdrawn = true;
        withdrawalTime = block.timestamp;
        return withdrawn;
    }

}