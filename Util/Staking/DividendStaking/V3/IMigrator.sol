// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

interface IMigrator {
    function migrate(address staker, uint256 migratedAmount) external view returns(bool);
}