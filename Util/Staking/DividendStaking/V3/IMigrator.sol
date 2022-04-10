// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

interface IMigrator {
    function migrate(address staker, uint256 migratedAmount) external returns(bool);
    function depositMigration(address _migrator, uint256 amount) external returns(bool);
}