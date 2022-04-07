// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

import './Context.sol';
import './ReentrancyGuard.sol';
import './Ownable.sol';
import './Pausable.sol';
import './SafeERC20.sol';
import './SafeMath.sol';
import './Math.sol';
import './EnumerableSet.sol';

contract Staking is Ownable, Pausable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
        uint256 pendingRewards;
        uint256 depositedAt;
        uint256 claimedAt;
    }
    
    struct autoCompounding{
        bool autoCompoundEnabled;
    }

    uint256 public lastUpdateTime;
    uint256 public accPerShare;
    uint256 public totalSupply;
    uint256 public totalReward;
    uint256 public collectedPenalty;
    uint256 currentIndex;

    IERC20 public immutable stakingToken;
    IERC20 public rewardToken;
    IERC20 public dividendToken;
    address public feeRecipient;
    uint256 public penaltyFee = 3;
    uint256 public constant MAX_FEE = 100;
    uint256 public constant FEE_LIMIT = 5; // 50%
    uint256 public rewardRate = uint256(0.00000001 ether);

    uint256 public endTime;
    uint256 public rewardCycle = 24 hours;
    mapping(address => UserInfo) public userInfo;
    mapping(address => autoCompounding) _autoCompound;
    EnumerableSet.AddressSet users;
    EnumerableSet.AddressSet autoCompound;
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event Claim(address indexed user, uint256 amount);
    event autoCompounder(address indexed user, bool autoCompound);
    event Compounded(address indexed compounder, uint256 amount);
    modifier updateUserList {
        _;
        if (userInfo[msg.sender].amount > 0 || userInfo[msg.sender].pendingRewards > 0) _checkOrAddUser(msg.sender);
        else _removeUser(msg.sender);
    }

    modifier updateCompoundlist {
        _;
        if(_autoCompound[msg.sender].autoCompoundEnabled) _checkOrAddCompounder(msg.sender);
        else _removeCompounder(msg.sender);
    }
    modifier updateReward {
        UserInfo storage user = userInfo[msg.sender];
        if (totalSupply > 0) {
            uint256 multiplier = Math.min(block.timestamp, endTime).sub(lastUpdateTime);
            uint256 reward = multiplier.mul(rewardRate);
            totalReward = totalReward.add(multiplier.mul(rewardRate));
            accPerShare = accPerShare.add(reward.mul(1e12).div(totalSupply));
        }
        lastUpdateTime = Math.min(block.timestamp, endTime);
        
        uint256 pending = user.amount.mul(accPerShare).div(1e12).sub(user.rewardDebt);
        user.pendingRewards = user.pendingRewards.add(pending);
        
        _;
        
        user.rewardDebt = user.amount.mul(accPerShare).div(1e12);
        if (user.claimedAt == 0) user.claimedAt = block.timestamp;
    }

    constructor(address _stakingToken, address _rewardToken, address _dividendToken) {
        stakingToken = IERC20(_stakingToken);
        rewardToken = IERC20(_rewardToken);
        dividendToken = IERC20(_dividendToken);
        feeRecipient = msg.sender;

        lastUpdateTime = block.timestamp;
        endTime = block.timestamp.add(36500 days); // In default, 100 years
    }

    function enableAutoCompound() external nonReentrant whenNotPaused updateCompoundlist{
        require(!_autoCompound[msg.sender].autoCompoundEnabled);
        _autoCompound[msg.sender].autoCompoundEnabled = true;
        emit autoCompounder(msg.sender,true);

    }

    function disableAutoCompound() external nonReentrant whenNotPaused updateCompoundlist{
        require(_autoCompound[msg.sender].autoCompoundEnabled);
        _autoCompound[msg.sender].autoCompoundEnabled = false;
        emit autoCompounder(msg.sender, false);
    }

    function setEndTime(uint256 _time) external onlyOwner {
        require (block.timestamp < _time, "!available");
        endTime = _time;
    }

    function restartPeriod(uint256 _minutes) external onlyOwner {
        require (block.timestamp > endTime, "!expired");
        endTime = block.timestamp.add(_minutes.mul(1 minutes));
        lastUpdateTime = block.timestamp;
    }

    function setRewardCycle(uint256 _cycleMinutes) external onlyOwner {
        rewardCycle = _cycleMinutes.mul(1 minutes);
    }

    function deposit(uint256 amount) external nonReentrant whenNotPaused updateReward updateUserList {
        require (block.timestamp < endTime, "expired");

        UserInfo storage user = userInfo[msg.sender];

        uint before = stakingToken.balanceOf(address(this));
        stakingToken.safeTransferFrom(msg.sender, address(this), amount);
        amount = stakingToken.balanceOf(address(this)).sub(before);

        user.amount = user.amount.add(amount);
        user.depositedAt = block.timestamp;
        totalSupply = totalSupply.add(amount);

        emit Deposit(msg.sender, amount);
    }

    function withdraw( uint256 amount) public nonReentrant updateReward updateUserList {
        UserInfo storage user = userInfo[msg.sender];

        if (penaltyFee == 0) {
            require(block.timestamp >= endTime, "You cannot withdraw yet!");
        }
        require(amount > 0 && user.amount >= amount, "!amount");

        uint256 feeAmount = 0;
        if (penaltyFee > 0 && block.timestamp < endTime) {
            feeAmount = amount.mul(penaltyFee).div(MAX_FEE);
        }
        
        // if (feeAmount > 0) stakingToken.safeTransfer(feeRecipient, feeAmount);
        collectedPenalty += feeAmount;
        stakingToken.safeTransfer(address(msg.sender), amount.sub(feeAmount));
        
        user.amount = user.amount.sub(amount);
        user.depositedAt = block.timestamp;
        totalSupply = totalSupply.sub(amount);

        emit Withdraw(msg.sender, amount);
    }

    function withdrawAll() external {
        UserInfo storage user = userInfo[msg.sender];

        withdraw(user.amount);
    }

    function withdrawPenalty() external onlyOwner {
        uint sendAmount = collectedPenalty;
        uint curBal = stakingToken.balanceOf(address(this));

        require (curBal > totalSupply, "!collected penalties");
        
        if (collectedPenalty > curBal.sub(totalSupply)) sendAmount = curBal.sub(totalSupply);
        stakingToken.safeTransfer(feeRecipient, sendAmount);
        collectedPenalty -= sendAmount;
    }

    function autoCoumpounded(uint256 index) internal {
        UserInfo storage user = userInfo[compoundList(index)];
        uint256 compoundedAmount = user.pendingRewards;
        _safeTransferDividends(compoundList(currentIndex), compoundedAmount);
        user.pendingRewards -= compoundedAmount;
        user.claimedAt = block.timestamp;
        user.amount += compoundedAmount;
        emit Compounded(compoundList(index), compoundedAmount);
    }

    function shouldAutoCompound(uint256 index) internal view returns(bool cycleDone) {
        return block.timestamp - userInfo[compoundList(index)].claimedAt >= rewardCycle;
    }

    function claim(uint256 gas) public nonReentrant updateReward updateUserList {
        require (block.timestamp.sub(userInfo[msg.sender].claimedAt) >= rewardCycle, "!available still");
        if(autoCompound.contains(msg.sender)) {
            UserInfo storage user = userInfo[msg.sender];
            uint256 compoundedAmount = user.pendingRewards;
            _safeTransferDividends(msg.sender, compoundedAmount);
            user.pendingRewards -= compoundedAmount;
            user.claimedAt = block.timestamp;
            user.amount += compoundedAmount;
            uint256 compoundIndex = compoundCount();
            uint256 gasUsed;
            uint256 gasLeft = gasleft();
            uint256 iterations;
            uint256 count;
            while(gasUsed < gas && iterations < compoundIndex){
                if(currentIndex >= compoundIndex) {
                    currentIndex = 0;
                }

                if(shouldAutoCompound(currentIndex)) {
                autoCoumpounded(currentIndex);
                count++;
                }
                gasUsed = gasUsed.add(gasLeft.sub(gasleft()));
                gasLeft = gasleft();
                currentIndex++;
                iterations++;
            }

            emit Compounded(msg.sender, compoundedAmount);
        } else {
            UserInfo storage user = userInfo[msg.sender];
            
            uint256 claimedAmount = _safeTransferRewards(msg.sender, user.pendingRewards);
            _safeTransferDividends(msg.sender, claimedAmount);
            user.pendingRewards = user.pendingRewards.sub(claimedAmount);
            user.claimedAt = block.timestamp;
            totalReward = totalReward.sub(claimedAmount);

            emit Claim(msg.sender, claimedAmount);
        }
    }

    function claimable(address _user) external view returns (uint256, uint256) {
        UserInfo storage user = userInfo[_user];
        if (user.amount == 0) return (user.pendingRewards, 0);
        uint256 curAccPerShare = accPerShare;
        uint256 curTotalReward = totalReward;
        if (totalSupply > 0) {
            uint256 multiplier = Math.min(block.timestamp, endTime).sub(lastUpdateTime);
            uint256 reward = multiplier.mul(rewardRate);
            curTotalReward += reward;
            curAccPerShare = accPerShare.add(reward.mul(1e12).div(totalSupply));
        }
        uint amount = user.amount;
        uint available = amount.mul(curAccPerShare).div(1e12).sub(user.rewardDebt).add(user.pendingRewards);

        uint reflectedAmount = dividendToken.balanceOf(address(this));
        uint dividendAmount = 0;
        if (curTotalReward > 0) {
            dividendAmount = reflectedAmount.mul(available).div(curTotalReward);
        }

        return (available, dividendAmount);
    }
    
    function _safeTransferRewards(address to, uint256 amount) internal returns (uint256) {
        uint256 _bal = rewardToken.balanceOf(address(this));
        if (address(rewardToken) == address(stakingToken)) {
            require (_bal.sub(totalSupply) > 0, "!enough rewards");
            if (amount > _bal.sub(totalSupply)) amount = _bal.sub(totalSupply);
        } else {
            require (_bal > 0, "!rewards");
            if (amount > _bal) amount = _bal;
        }
        if (amount > totalReward) amount = totalReward;
        rewardToken.safeTransfer(to, amount);
        return amount;
    }

    function _safeTransferDividends(address _to, uint256 _rewardAmount) internal returns (uint256) {
        uint reflectedAmount = dividendToken.balanceOf(address(this));
        if (reflectedAmount == 0 || totalReward == 0) return 0;
        require (_rewardAmount <= totalReward, "invalid reward amount");

        uint dividendAmount = reflectedAmount.mul(_rewardAmount).div(totalReward);
        if (dividendAmount > 0) {
            dividendToken.safeTransfer(_to, dividendAmount);
        }
        return dividendAmount;
    }
    
    function setRewardRate(uint256 _rewardRate) external onlyOwner {
        require (endTime > block.timestamp, "expired");
        require (_rewardRate > 0, "Rewards per second should be greater than 0!");

        // Update pool infos with old reward rate before setting new one first
        if (totalSupply > 0) {
            uint256 multiplier = block.timestamp.sub(lastUpdateTime);
            uint256 reward = multiplier.mul(rewardRate);
            totalReward = totalReward.add(reward);
            accPerShare = accPerShare.add(reward.mul(1e12).div(totalSupply));    
        }
        lastUpdateTime = block.timestamp;
        rewardRate = _rewardRate;
    }

    function setPenaltyFee(uint256 _fee) external onlyOwner {
        require(_fee < FEE_LIMIT, "invalid fee");

        penaltyFee = _fee;
    }

    function setFeeRecipient(address _recipient) external onlyOwner {
        feeRecipient = _recipient;
    }

    function _removeCompounder(address _user) internal {
        if (autoCompound.contains(_user)) {
            autoCompound.remove(_user);
        }
    }

    function _checkOrAddCompounder(address _user) internal {
        if (!autoCompound.contains(_user)) {
            autoCompound.add(_user);
        }
    }

    function compoundCount() public view returns (uint) {
        return autoCompound.length();
    }

    function compoundList(uint256 index) public view onlyOwner returns (address indexedAddress) {
        indexedAddress = autoCompound.at(index);
        return indexedAddress;
    }

    function _removeUser(address _user) internal {
        if (users.contains(_user)) {
            users.remove(_user);
        }
    }

    function _checkOrAddUser(address _user) internal {
        if (!users.contains(_user)) {
            users.add(_user);
        }
    }

    function userCount() public view returns (uint) {
        return users.length();
    }

    function userList() public view onlyOwner returns (address[] memory) {
        address[] memory list = new address[](users.length());

        for (uint256 i = 0; i < users.length(); i++) {
            list[i] = users.at(i);
        }

        return list;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}