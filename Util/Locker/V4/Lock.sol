// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;
import "./ReentrancyGuard.sol";
import "./IBEP20.sol";
import "./ILocker.sol";

contract Lock is ReentrancyGuard, ILocker {

    address public token;
    address public lockOwner;
    address public mainLocker;
    uint256 public initalTokenAmount;
    uint256 public tokenAmount;
    uint256 public dateLocked;
    uint256 public unlockTime;
    uint256 public withdrawalTime;
    uint256 public Id;
    bool public withdrawn;

    mapping(address => mapping(address => uint256)) public walletTokenBalance;

    modifier onlyLocker() {
        require(msg.sender == mainLocker); _;
    }

    constructor(address _token, address _lockOwner, uint256 amount, uint256 _unlockTime, uint256 _id, bool isNFT) payable {
        if(isNFT){
            mainLocker = address(0x0);
            token = _token;
            lockOwner = _lockOwner;
            initalTokenAmount = amount;
            Id = _id;
            tokenAmount = initalTokenAmount;
            dateLocked = block.timestamp;
            unlockTime = _unlockTime;
            walletTokenBalance[_token][_lockOwner] += amount;
        }  else {
            mainLocker = address(0x0);
            token = _token;
            lockOwner = _lockOwner;
            initalTokenAmount = amount;
            Id = _id;
            tokenAmount = initalTokenAmount;
            dateLocked = block.timestamp;
            unlockTime = _unlockTime;
            walletTokenBalance[_token][_lockOwner] += amount;
        }
    }

    function getWithdrawalTime() external override view returns(uint256) {
        if(unlockTime >= block.timestamp) {
            return block.timestamp - unlockTime;
        } else {
            return unlockTime - block.timestamp;

        }
    }

    function getId() external override view returns(uint256) {
        return Id;
    }

    function getTotalTokenBalance() public override view returns (uint256){
        return tokenAmount;
    }

    function getTokenAddress() external override view returns(address){
        return token;
    }

    function getUnlockTime() external view override returns(uint256) {
        return unlockTime;
    }
    
    function increaseLockAmount(uint256 amount) external override onlyLocker returns(bool increased){
        tokenAmount += amount;
        walletTokenBalance[token][lockOwner] += tokenAmount;
        increased = true;
        return increased;
    }

    function transferLockOwnership(address _lockOwner) external override onlyLocker returns(bool transferred){
        uint256 previousBalance = walletTokenBalance[token][lockOwner];
        walletTokenBalance[token][lockOwner] = previousBalance - tokenAmount;        
        walletTokenBalance[token][_lockOwner] += tokenAmount;
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

    function withdrawTokens(address wAddress) external override onlyLocker returns(bool){
        if(wAddress == address(0)) {
            require(IBEP20(token).transfer(lockOwner, tokenAmount), 'Failed to transfer tokens');
            uint256 previousBalance = walletTokenBalance[token][lockOwner];
            walletTokenBalance[token][lockOwner] = previousBalance - tokenAmount;
            withdrawn = true;
            withdrawalTime = block.timestamp;
            return withdrawn;
        } else {
            require(IBEP20(token).transfer(wAddress, tokenAmount), 'Failed to transfer tokens');
            uint256 previousBalance = walletTokenBalance[token][lockOwner];
            walletTokenBalance[token][lockOwner] = previousBalance - tokenAmount;
            withdrawn = true;
            withdrawalTime = block.timestamp;
            return withdrawn;
        }
    }
}