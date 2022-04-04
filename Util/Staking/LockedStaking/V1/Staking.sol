pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT
import "./IBEP20.sol";
import "./SafeMath.sol";

contract Staking {
    using SafeMath for uint256;
    IBEP20 public token;
    address payable public owner;

    uint256 public totalStakedToken;
    uint256 public totalUnStakedToken;
    uint256 public totalWithdrawanToken;
    uint256 public totalClaimedRewardToken;
    uint256 public totalStakers;
    uint256 public unstakePercent = 100;
    uint256 public percentDivider = 1000;

    uint256[4] public Duration = [
        7 days,
        30 days,
        90 days,
        180 days
    ];
    uint256[4] public Bonus = [50, 100, 150, 200];
    uint256[4] public totalStakedPerPlan;
    uint256[4] public totalStakersPerPlan;

    struct Stake {
        uint256 plan;
        uint256 withdrawtime;
        uint256 staketime;
        uint256 amount;
        uint256 reward;
        uint256 persecondreward;
        bool withdrawan;
        bool unstaked;
    }

    struct User {
        uint256 totalStakedTokenUser;
        uint256 totalWithdrawanTokenUser;
        uint256 totalUnStakedTokenUser;
        uint256 totalClaimedRewardTokenUser;
        uint256 stakeCount;
        bool alreadyExists;
    }

    mapping(address => User) public Stakers;
    mapping(address => mapping(uint256 => Stake)) public stakersRecord;
    mapping(address => mapping(uint256 => uint256)) public userStakedPerPlan;
    mapping(address => uint256) public stakedTokens;

    event STAKE(address Staker, uint256 amount);
    event UNSTAKE(address Staker, uint256 amount);
    event WITHDRAW(address Staker, uint256 amount);

    modifier onlyowner() {
        require(owner == msg.sender, "only owner");
        _;
    }

    constructor(address _owner, address _token) {
        owner = payable(_owner);
        token = IBEP20(_token);
    }

    function stake(uint256 amount, uint256 planIndex) public {
        require(planIndex >= 0 && planIndex <= 4, "Invalid Time Period");
        require(amount >= 0, "stake more than 0");
        require(token.balanceOf(msg.sender) >= amount,"insufficient balance");

        if (!Stakers[msg.sender].alreadyExists) {
            Stakers[msg.sender].alreadyExists = true;
            totalStakers++;
        }

        uint256 index = Stakers[msg.sender].stakeCount;
        Stakers[msg.sender].totalStakedTokenUser = Stakers[msg.sender]
            .totalStakedTokenUser
            .add(amount);
        stakedTokens[msg.sender] = stakedTokens[msg.sender].add(amount);
        totalStakedToken = totalStakedToken.add(amount);
        stakersRecord[msg.sender][index].withdrawtime = block.timestamp.add(
            Duration[planIndex]
        );
        stakersRecord[msg.sender][index].staketime = block.timestamp;
        stakersRecord[msg.sender][index].amount = amount;
        stakersRecord[msg.sender][index].reward = amount
            .mul(Bonus[planIndex])
            .div(percentDivider);
        stakersRecord[msg.sender][index].persecondreward = stakersRecord[
            msg.sender
        ][index].reward.div(Duration[planIndex]);
        stakersRecord[msg.sender][index].plan = planIndex;
        Stakers[msg.sender].stakeCount++;
        userStakedPerPlan[msg.sender][planIndex] = userStakedPerPlan[
            msg.sender
        ][planIndex].add(amount);
        totalStakedPerPlan[planIndex] = totalStakedPerPlan[planIndex].add(
            amount
        );
        totalStakersPerPlan[planIndex]++;

        emit STAKE(msg.sender, amount);
    }

    function unstake(uint256 index) public {
        require(
            !stakersRecord[msg.sender][index].withdrawan,
            "already withdrawan"
        );
        require(!stakersRecord[msg.sender][index].unstaked, "already unstaked");
        require(index < Stakers[msg.sender].stakeCount,"Invalid index");

        uint256 _amount = stakersRecord[msg.sender][index].amount;
        uint256 deductionAmount = unstakeDeductionAmount(msg.sender ,index);
        stakersRecord[msg.sender][index].unstaked = true;
        token.transferFrom(
            msg.sender,
            owner,
            deductionAmount
        );
        stakedTokens[msg.sender] = stakedTokens[msg.sender].sub(_amount);
        totalUnStakedToken = totalUnStakedToken.add(
            _amount
        );
        Stakers[msg.sender].totalUnStakedTokenUser = Stakers[msg.sender]
            .totalUnStakedTokenUser
            .add(_amount);
        uint256 planIndex = stakersRecord[msg.sender][index].plan;
        userStakedPerPlan[msg.sender][planIndex] = userStakedPerPlan[
            msg.sender
        ][planIndex].sub(_amount, "user stake");
        totalStakedPerPlan[planIndex] = totalStakedPerPlan[planIndex].sub(
            _amount,
            "total stake"
        );
        totalStakersPerPlan[planIndex]--;

        emit UNSTAKE(msg.sender, _amount);
    }

    function withdraw(uint256 index) public {
        require(
            !stakersRecord[msg.sender][index].withdrawan,
            "already withdrawan"
        );
        require(!stakersRecord[msg.sender][index].unstaked, "already unstaked");
        require(
            stakersRecord[msg.sender][index].withdrawtime < block.timestamp,
            "cannot withdraw before stake duration"
        );
        require(index < Stakers[msg.sender].stakeCount,"Invalid index");

        uint256 _amount = stakersRecord[msg.sender][index].amount;
        stakersRecord[msg.sender][index].withdrawan = true;
        
        token.transferFrom(
            owner,
            msg.sender,
            stakersRecord[msg.sender][index].reward
        );
        stakedTokens[msg.sender] = stakedTokens[msg.sender].sub(_amount);
        totalWithdrawanToken = totalWithdrawanToken.add(
            _amount
        );
        totalClaimedRewardToken = totalClaimedRewardToken.add(
            stakersRecord[msg.sender][index].reward
        );
        Stakers[msg.sender].totalWithdrawanTokenUser = Stakers[msg.sender]
            .totalWithdrawanTokenUser
            .add(_amount);
        Stakers[msg.sender].totalClaimedRewardTokenUser = Stakers[msg.sender]
            .totalClaimedRewardTokenUser
            .add(stakersRecord[msg.sender][index].reward);
        uint256 planIndex = stakersRecord[msg.sender][index].plan;
        userStakedPerPlan[msg.sender][planIndex] = userStakedPerPlan[
            msg.sender
        ][planIndex].sub(_amount, "user stake");
        totalStakedPerPlan[planIndex] = totalStakedPerPlan[planIndex].sub(
            _amount,
            "total stake"
        );
        totalStakersPerPlan[planIndex]--;

        emit WITHDRAW(
            msg.sender,
            stakersRecord[msg.sender][index].reward.add(
                _amount
            )
        );
    }

    function unstakeDeductionAmount(address user, uint256 index) public view returns(uint256) {
        uint256 _amount = stakersRecord[user][index].amount;
        return _amount.mul(unstakePercent).div(percentDivider);
    }

    function SetStakeDuration(
        uint256 first,
        uint256 second,
        uint256 third,
        uint256 fourth
    ) external onlyowner {
        Duration[0] = first;
        Duration[1] = second;
        Duration[2] = third;
        Duration[3] = fourth;
    }

    function SetStakeBonus(
        uint256 first,
        uint256 second,
        uint256 third,
        uint256 fourth
    ) external onlyowner {
        Bonus[0] = first;
        Bonus[1] = second;
        Bonus[2] = third;
        Bonus[3] = fourth;
    }

    function setUnstakePercent(uint256 _percent) external onlyowner {
        unstakePercent = _percent;
    }

    function setPercentDivider(uint256 _divider) external onlyowner {
        percentDivider = _divider;
    }

    function changeOwner(address payable _owner) external onlyowner {
        owner = _owner;
    }

    function changeToken(address _token) external onlyowner {
        token = IBEP20(_token);
    }

    function removeStuckToken(address _token) external onlyowner {
        IBEP20(_token).transfer(owner, IBEP20(_token).balanceOf(address(this)));
    }

    function realtimeReward(address user) public view returns (uint256) {
        uint256 ret;
        for (uint256 i; i < Stakers[user].stakeCount; i++) {
            if (
                !stakersRecord[user][i].withdrawan &&
                !stakersRecord[user][i].unstaked
            ) {
                uint256 val;
                val = block.timestamp - stakersRecord[user][i].staketime;
                val = val.mul(stakersRecord[user][i].persecondreward);
                if (val < stakersRecord[user][i].reward) {
                    ret += val;
                } else {
                    ret += stakersRecord[user][i].reward;
                }
            }
        }
        return ret;
    }
}
}