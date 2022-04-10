// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

import './Pausable.sol';
import './SafeERC20.sol';
import './SafeMath.sol';
import './Math.sol';
import './IMigrator.sol';
import './Ownable.sol';

contract Migrator is IMigrator, Pausable, Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address oldStakingPool;
    address newStakingPool;
    IERC20 public immutable stakingToken;
    IMigrator public migrator;
    IMigrator public newPool;
    uint256 migrationSet;
    constructor(address _stakingToken) {
        stakingToken = IERC20(_stakingToken);
        migrator = IMigrator(address(this));
    }

    function setPools(address oldPool, address _newPool) external onlyOwner {
        require(migrationSet + 7 days >= block.timestamp);
        oldStakingPool = oldPool;
        newStakingPool = _newPool;
        newPool = IMigrator(_newPool);
        migrationSet = block.timestamp;
    }

    function depositMigration(address _migrator, uint256 amount) external override whenNotPaused returns(bool) {
        require(address(oldStakingPool) == msg.sender);
        stakingToken.safeTransferFrom(msg.sender, address(this), amount);
        migrator.migrate(_migrator, amount);
        return true;
    }

    function migrate(address staker, uint256 migratedAmount) public override whenNotPaused returns(bool){
        require(address(this) == msg.sender);
        require(newPool.depositMigration(staker, migratedAmount));
        return true;
    }
}
